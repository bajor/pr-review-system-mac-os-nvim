import Foundation

/// Polls GitHub for PR updates at configured intervals
public final class PRPoller: @unchecked Sendable {
    // MARK: - Types

    /// Represents a change detected in a PR
    public struct PRChange: Equatable, Sendable {
        public let pr: PullRequest
        public let repo: String
        public let changeType: ChangeType

        public enum ChangeType: Equatable, Sendable {
            case newPR
            case newCommits(oldSHA: String, newSHA: String)
            case newComments(count: Int)
            case statusChanged(from: String?, to: String?)
        }
    }

    /// Callback for when changes are detected
    public typealias ChangeHandler = @Sendable ([PRChange]) -> Void

    // MARK: - Properties

    /// Configuration (used for repo list and token resolution)
    private let config: Config

    /// Polling timer
    private var timer: Timer?

    /// Last known PR states (repo -> [pr number -> state])
    private var lastKnownStates: [String: [Int: PRState]] = [:]

    /// Cached discovered repos (when config.repos is empty)
    private var discoveredRepos: [String]?

    /// Change handler callback
    private var onChanges: ChangeHandler?

    /// Serial queue for thread-safe state access
    private let stateQueue = DispatchQueue(label: "com.pr-review.poller.state")

    /// Whether polling is active
    public private(set) var isPolling: Bool = false

    // MARK: - Initialization

    public init(config: Config) {
        self.config = config
    }

    // MARK: - Private Helpers

    /// Create a GitHub API client for the given owner
    private func api(for owner: String) -> GitHubAPI {
        let token = config.resolveToken(for: owner)
        return GitHubAPI(token: token)
    }

    /// Discover all repos accessible by configured tokens
    private func discoverRepos() async -> [String] {
        var allRepos: Set<String> = []

        await withTaskGroup(of: [String].self) { group in
            // Discover repos from each token in the tokens map
            for (_, token) in config.tokens {
                group.addTask {
                    let api = GitHubAPI(token: token)
                    do {
                        let repos = try await api.listRepos()
                        return repos.map { $0.fullName }
                    } catch {
                        print("Error discovering repos: \(error)")
                        return []
                    }
                }
            }

            // Also check default token if not empty and not already in tokens
            if !config.githubToken.isEmpty {
                let tokenAlreadyUsed = config.tokens.values.contains(config.githubToken)
                if !tokenAlreadyUsed {
                    group.addTask {
                        let api = GitHubAPI(token: self.config.githubToken)
                        do {
                            let repos = try await api.listRepos()
                            return repos.map { $0.fullName }
                        } catch {
                            print("Error discovering repos with default token: \(error)")
                            return []
                        }
                    }
                }
            }

            for await repos in group {
                for repo in repos {
                    allRepos.insert(repo)
                }
            }
        }

        return Array(allRepos).sorted()
    }

    /// Get repos to poll - either from config or auto-discovered
    private func getReposToPoll() async -> [String] {
        if !config.repos.isEmpty {
            return config.repos
        }

        // Check cache first
        if let cached = stateQueue.sync(execute: { discoveredRepos }) {
            return cached
        }

        // Discover repos
        let discovered = await discoverRepos()
        stateQueue.sync {
            discoveredRepos = discovered
        }
        return discovered
    }

    // MARK: - Public API

    /// Start polling for PR updates
    /// - Parameter onChanges: Callback invoked when changes are detected
    public func startPolling(onChanges: @escaping ChangeHandler) {
        stateQueue.sync {
            guard !isPolling else { return }
            self.onChanges = onChanges
            isPolling = true
        }

        // Schedule timer on main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let interval = TimeInterval(self.config.pollIntervalSeconds)
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task {
                    await self?.poll()
                }
            }

            // Initial poll immediately
            Task {
                await self.poll()
            }
        }
    }

    /// Stop polling
    public func stopPolling() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }

        stateQueue.sync {
            isPolling = false
            onChanges = nil
        }
    }

    /// Force an immediate poll
    public func pollNow() async {
        await poll()
    }

    /// Clear cached state (useful for testing)
    public func clearState() {
        stateQueue.sync {
            lastKnownStates.removeAll()
            discoveredRepos = nil
        }
    }

    // MARK: - Private Methods

    /// Perform a poll cycle
    private func poll() async {
        var allChanges: [PRChange] = []

        let reposToPoll = await getReposToPoll()

        for repo in reposToPoll {
            let parts = repo.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repoName = String(parts[1])

            // Get API with owner-specific token
            let repoAPI = api(for: owner)

            do {
                let prs = try await repoAPI.listPRs(owner: owner, repo: repoName)
                let changes = detectChanges(for: repo, prs: prs)
                allChanges.append(contentsOf: changes)

                // Update stored state
                updateState(for: repo, prs: prs)
            } catch {
                // Log error but continue with other repos
                print("Error polling \(repo): \(error)")
            }
        }

        // Filter out changes by the current user
        let filteredChanges = allChanges.filter { change in
            change.pr.user.login != config.githubUsername
        }

        // Notify if there are changes
        if !filteredChanges.isEmpty {
            let handler = stateQueue.sync { onChanges }
            handler?(filteredChanges)
        }
    }

    /// Detect changes between current and previous state
    private func detectChanges(for repo: String, prs: [PullRequest]) -> [PRChange] {
        var changes: [PRChange] = []

        let previousStates = stateQueue.sync { lastKnownStates[repo] ?? [:] }

        for pr in prs {
            if let previousState = previousStates[pr.number] {
                // Check for commit changes
                if pr.head.sha != previousState.headSHA {
                    changes.append(PRChange(
                        pr: pr,
                        repo: repo,
                        changeType: .newCommits(oldSHA: previousState.headSHA, newSHA: pr.head.sha)
                    ))
                }

                // Check for comment count changes
                // Note: This is a simple heuristic - for accurate tracking we'd need to fetch comments
                // and compare. For now, we rely on PR metadata updates.
            } else {
                // New PR
                changes.append(PRChange(
                    pr: pr,
                    repo: repo,
                    changeType: .newPR
                ))
            }
        }

        return changes
    }

    /// Update stored state with current PR data
    private func updateState(for repo: String, prs: [PullRequest]) {
        var newStates: [Int: PRState] = [:]
        for pr in prs {
            newStates[pr.number] = PRState(
                headSHA: pr.head.sha,
                updatedAt: pr.updatedAt
            )
        }

        stateQueue.sync {
            lastKnownStates[repo] = newStates
        }
    }
}

// MARK: - Supporting Types

/// Cached state for a PR
private struct PRState {
    let headSHA: String
    let updatedAt: Date
}
