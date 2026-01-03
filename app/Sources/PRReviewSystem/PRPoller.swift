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

    /// GitHub API client
    private let api: GitHubAPI

    /// Configuration
    private let config: Config

    /// Polling timer
    private var timer: Timer?

    /// Last known PR states (repo -> [pr number -> state])
    private var lastKnownStates: [String: [Int: PRState]] = [:]

    /// Change handler callback
    private var onChanges: ChangeHandler?

    /// Serial queue for thread-safe state access
    private let stateQueue = DispatchQueue(label: "com.pr-review.poller.state")

    /// Whether polling is active
    public private(set) var isPolling: Bool = false

    // MARK: - Initialization

    public init(api: GitHubAPI, config: Config) {
        self.api = api
        self.config = config
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
        }
    }

    // MARK: - Private Methods

    /// Perform a poll cycle
    private func poll() async {
        var allChanges: [PRChange] = []

        for repo in config.repos {
            let parts = repo.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repoName = String(parts[1])

            do {
                let prs = try await api.listPRs(owner: owner, repo: repoName)
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
