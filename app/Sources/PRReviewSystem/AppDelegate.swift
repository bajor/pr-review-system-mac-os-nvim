import AppKit
import Foundation
import UserNotifications

/// Application delegate for the menu bar app
public final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    /// Menu bar controller
    private let menuBarController = MenuBarController.shared

    /// Notification manager (lazy to avoid startup crash)
    private lazy var notificationManager: NotificationManager = {
        NotificationManager.shared
    }()

    /// GitHub API client
    private var githubAPI: GitHubAPI?

    /// Current configuration
    private var config: Config?

    /// Ghostty launcher
    private var launcher: GhosttyLauncher?

    /// PR poller for background updates
    private var poller: PRPoller?

    /// Cleanup service for old PR directories
    private var cleanupService: CleanupService?

    /// Timer for polling pending check statuses
    private var checkStatusTimer: Timer?

    /// Interval for polling pending checks (30 seconds)
    private let checkStatusPollInterval: TimeInterval = 30

    // MARK: - Application Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Set up menu bar
        menuBarController.setup()

        // Load configuration
        loadConfiguration()

        // Register for notifications
        registerNotifications()

        // Setup notification manager callback
        setupNotificationManager()

        // Request notification permissions
        requestNotificationPermissions()

        // Run cleanup if needed
        runCleanupIfNeeded()

        // Start polling
        startPolling()

        // Initial refresh
        Task {
            await refreshPullRequests()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        // Stop polling
        poller?.stopPolling()
        checkStatusTimer?.invalidate()
        checkStatusTimer = nil
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        do {
            config = try ConfigLoader.load()
            githubAPI = GitHubAPI(token: config!.githubToken)
            launcher = GhosttyLauncher(config: config!)
            cleanupService = CleanupService(config: config!)

            // Configure notification manager from config
            notificationManager.soundEnabled = config!.notifications.sound
            notificationManager.customSoundPath = config!.notifications.soundPath
        } catch {
            // Show error notification
            notificationManager.notify(
                title: "Configuration Error",
                body: "Failed to load configuration: \(error.localizedDescription)"
            )
        }
    }

    private func runCleanupIfNeeded() {
        guard let cleanup = cleanupService else { return }

        // Run cleanup in background if needed
        if cleanup.shouldRunCleanup() {
            DispatchQueue.global(qos: .background).async {
                let result = cleanup.runCleanup()
                if result.deletedCount > 0 {
                    print("Cleaned up \(result.deletedCount) old PR directories, freed \(String(format: "%.1f", result.freedMB)) MB")
                }
                for error in result.errors {
                    print("Cleanup error: \(error)")
                }
            }
        }
    }

    private func setupNotificationManager() {
        notificationManager.onOpenPR = { [weak self] prURL in
            Task {
                await self?.openPRByURL(prURL)
            }
        }
    }

    private func startPolling() {
        guard let api = githubAPI, let config = config else { return }

        poller = PRPoller(api: api, config: config)
        poller?.startPolling { [weak self] changes in
            self?.handlePRChanges(changes)
        }
    }

    private func handlePRChanges(_ changes: [PRPoller.PRChange]) {
        guard let config = config else { return }

        for change in changes {
            switch change.changeType {
            case .newPR:
                if config.notifications.newComments { // Using newComments as general notifications flag
                    notificationManager.notifyNewPR(
                        title: change.pr.title,
                        repo: change.repo,
                        author: change.pr.user.login,
                        prURL: change.pr.htmlUrl
                    )
                }

            case .newCommits:
                if config.notifications.newCommits {
                    notificationManager.notifyNewCommits(
                        prTitle: change.pr.title,
                        repo: change.repo,
                        prNumber: change.pr.number,
                        commitCount: 1, // We don't track exact count
                        prURL: change.pr.htmlUrl
                    )
                }

            case let .newComments(count):
                if config.notifications.newComments {
                    notificationManager.notifyNewComments(
                        prTitle: change.pr.title,
                        repo: change.repo,
                        prNumber: change.pr.number,
                        commentCount: count,
                        prURL: change.pr.htmlUrl
                    )
                }

            case let .statusChanged(_, to):
                if let status = to {
                    notificationManager.notifyPRStatusChange(
                        prTitle: change.pr.title,
                        repo: change.repo,
                        prNumber: change.pr.number,
                        status: status,
                        prURL: change.pr.htmlUrl
                    )
                }
            }
        }

        // Refresh the menu after detecting changes
        Task {
            await refreshPullRequests()
        }
    }

    // MARK: - Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePRSelected(_:)),
            name: .prSelected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRefreshRequested),
            name: .refreshRequested,
            object: nil
        )
    }

    private func requestNotificationPermissions() {
        Task {
            _ = await notificationManager.requestPermissions()
        }
    }

    // MARK: - Notification Handlers

    @objc private func handlePRSelected(_ notification: Notification) {
        guard let pr = notification.userInfo?["pr"] as? PullRequest else { return }

        Task {
            await openPRInNeovim(pr)
        }
    }

    @objc private func handleRefreshRequested() {
        Task {
            await refreshPullRequests()
        }
    }

    // MARK: - Pull Request Fetching

    private func refreshPullRequests() async {
        guard let config = config, let api = githubAPI else {
            return
        }

        // Fetch all repos in parallel
        let allPRs = await withTaskGroup(of: (String, [PRDisplayInfo])?.self) { group in
            for repo in config.repos {
                group.addTask {
                    // Parse owner/repo from the repo string
                    let parts = repo.split(separator: "/")
                    guard parts.count == 2 else { return nil }
                    let owner = String(parts[0])
                    let repoName = String(parts[1])

                    do {
                        let prs = try await api.listPRs(owner: owner, repo: repoName)
                        if prs.isEmpty { return nil }

                        // Create display info
                        let prInfos = prs.map { PRDisplayInfo(pr: $0) }
                        return (repo, prInfos)
                    } catch {
                        print("Error fetching PRs for \(repo): \(error)")
                        return nil
                    }
                }
            }

            // Collect results
            var results: [String: [PRDisplayInfo]] = [:]
            for await result in group {
                if let (repo, prInfos) = result {
                    results[repo] = prInfos
                }
            }
            return results
        }

        // Update menu immediately with PR list
        await MainActor.run {
            menuBarController.updatePullRequests(allPRs)
        }

        // Fetch commit messages and check statuses in parallel (fire and forget)
        for (repo, prInfos) in allPRs {
            let parts = repo.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repoName = String(parts[1])

            for prInfo in prInfos {
                // Fetch commit message
                Task {
                    do {
                        if let commit = try await api.getLastCommit(owner: owner, repo: repoName, number: prInfo.pr.number) {
                            await MainActor.run {
                                menuBarController.updateCommitMessage(
                                    forPR: prInfo.pr.number,
                                    inRepo: repo,
                                    message: commit.summary
                                )
                            }
                        }
                    } catch {
                        print("Error fetching commit for PR #\(prInfo.pr.number): \(error)")
                    }
                }

                // Fetch check status
                Task {
                    await fetchCheckStatus(for: prInfo.pr, in: repo, owner: owner, repoName: repoName)
                }
            }
        }

        // Start or update the check status polling timer
        await MainActor.run {
            startCheckStatusPollingIfNeeded()
        }
    }

    /// Fetch check status for a single PR
    private func fetchCheckStatus(for pr: PullRequest, in repo: String, owner: String, repoName: String) async {
        guard let api = githubAPI else { return }

        do {
            let status = try await api.getCheckStatus(owner: owner, repo: repoName, ref: pr.head.sha)
            await MainActor.run {
                menuBarController.updateCheckStatus(
                    forPR: pr.number,
                    inRepo: repo,
                    status: status,
                    sha: pr.head.sha
                )
            }
        } catch {
            print("Error fetching check status for PR #\(pr.number): \(error)")
        }
    }

    /// Start polling for pending check statuses
    private func startCheckStatusPollingIfNeeded() {
        // Invalidate existing timer
        checkStatusTimer?.invalidate()

        // Check if there are any pending checks
        let pendingPRs = menuBarController.getPRsWithPendingChecks()
        guard !pendingPRs.isEmpty else {
            checkStatusTimer = nil
            return
        }

        // Start polling timer
        checkStatusTimer = Timer.scheduledTimer(withTimeInterval: checkStatusPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollPendingCheckStatuses()
            }
        }
    }

    /// Poll check statuses for PRs with pending checks
    private func pollPendingCheckStatuses() async {
        guard githubAPI != nil else { return }

        let pendingPRs = await MainActor.run {
            menuBarController.getPRsWithPendingChecks()
        }

        guard !pendingPRs.isEmpty else {
            // No more pending checks, stop the timer
            await MainActor.run {
                checkStatusTimer?.invalidate()
                checkStatusTimer = nil
            }
            return
        }

        // Fetch status for each pending PR
        for (repo, pr, _) in pendingPRs {
            let parts = repo.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repoName = String(parts[1])

            await fetchCheckStatus(for: pr, in: repo, owner: owner, repoName: repoName)
        }

        // Check if we still have pending checks
        let stillPending = await MainActor.run {
            menuBarController.getPRsWithPendingChecks()
        }

        if stillPending.isEmpty {
            await MainActor.run {
                checkStatusTimer?.invalidate()
                checkStatusTimer = nil
            }
        }
    }

    // MARK: - PR Opening

    private func openPRInNeovim(_ pr: PullRequest) async {
        guard let launcher = launcher else {
            notificationManager.notify(
                title: "Not Configured",
                body: "Please configure the application first"
            )
            return
        }

        // Extract owner/repo from the PR
        guard let repoFullName = pr.head.repo?.fullName else {
            // Fallback to just opening by URL
            do {
                try await launcher.openPRByURL(pr.htmlUrl)
            } catch {
                notificationManager.notify(
                    title: "Failed to Open PR",
                    body: error.localizedDescription
                )
            }
            return
        }

        let parts = repoFullName.split(separator: "/")
        guard parts.count == 2 else {
            try? await launcher.openPRByURL(pr.htmlUrl)
            return
        }

        let owner = String(parts[0])
        let repo = String(parts[1])

        do {
            try await launcher.openPR(pr, owner: owner, repo: repo)
        } catch {
            notificationManager.notify(
                title: "Failed to Open PR",
                body: error.localizedDescription
            )
        }
    }

    /// Open a PR by URL (used by notification manager callback)
    private func openPRByURL(_ url: String) async {
        guard let launcher = launcher else {
            notificationManager.notify(
                title: "Not Configured",
                body: "Please configure the application first"
            )
            return
        }

        do {
            try await launcher.openPRByURL(url)
        } catch {
            notificationManager.notify(
                title: "Failed to Open PR",
                body: error.localizedDescription
            )
        }
    }
}
