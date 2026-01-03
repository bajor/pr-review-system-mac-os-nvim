import AppKit
import Foundation

/// PR with additional display info
public struct PRDisplayInfo {
    public let pr: PullRequest
    public var lastCommitMessage: String?
    public var checkStatus: CheckStatus?
    public var lastCheckedSHA: String?  // Track which SHA we last checked

    public init(pr: PullRequest, lastCommitMessage: String? = nil, checkStatus: CheckStatus? = nil) {
        self.pr = pr
        self.lastCommitMessage = lastCommitMessage
        self.checkStatus = checkStatus
        self.lastCheckedSHA = pr.head.sha
    }
}

/// Manages the menu bar status item and menu
public final class MenuBarController: NSObject {
    // MARK: - Properties

    /// The status item displayed in the menu bar
    private var statusItem: NSStatusItem?

    /// The menu displayed when clicking the status item
    private var menu: NSMenu?

    /// Current pull requests grouped by repository (with display info)
    private var pullRequests: [String: [PRDisplayInfo]] = [:]

    /// Badge count (number of PRs needing review)
    private var badgeCount: Int = 0

    /// Shared instance
    public static let shared = MenuBarController()

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Set up the menu bar status item
    public func setup() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure button
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Set initial display
        updateStatusDisplay()

        // Create initial menu
        rebuildMenu()
    }

    // MARK: - Status Image

    /// Update the status item display with PR text and badge
    private func updateStatusDisplay() {
        guard let button = statusItem?.button else { return }

        // Create attributed string for "PR" text
        let prText = badgeCount > 0 ? "PR \(badgeCount)" : "PR"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.controlTextColor
        ]
        button.attributedTitle = NSAttributedString(string: prText, attributes: attributes)
        button.image = nil
    }

    /// Update the status item with badge count
    public func updateBadge(count: Int) {
        badgeCount = count
        updateStatusDisplay()
    }

    // MARK: - Menu Actions

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click shows context menu
            showMenu()
        } else {
            // Left-click also shows menu (or could toggle popover)
            showMenu()
        }
    }

    private func showMenu() {
        guard let button = statusItem?.button else { return }
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil // Reset to allow custom click handling
    }

    // MARK: - Menu Building

    /// Rebuild the menu with current pull requests
    public func rebuildMenu() {
        let newMenu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "PR Review System", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        newMenu.addItem(headerItem)

        newMenu.addItem(NSMenuItem.separator())

        // Pull requests grouped by repo
        if pullRequests.isEmpty {
            let noPRsItem = NSMenuItem(title: "No PRs awaiting review", action: nil, keyEquivalent: "")
            noPRsItem.isEnabled = false
            newMenu.addItem(noPRsItem)
        } else {
            for (repo, prInfos) in pullRequests.sorted(by: { $0.key < $1.key }) {
                // Repository header
                let repoItem = NSMenuItem(title: repo, action: nil, keyEquivalent: "")
                repoItem.isEnabled = false
                if let font = NSFont.boldSystemFont(ofSize: 12) as NSFont? {
                    repoItem.attributedTitle = NSAttributedString(
                        string: repo,
                        attributes: [.font: font]
                    )
                }
                newMenu.addItem(repoItem)

                // PR items
                for prInfo in prInfos {
                    let prItem = createPRMenuItem(prInfo: prInfo)
                    newMenu.addItem(prItem)
                }

                newMenu.addItem(NSMenuItem.separator())
            }
        }

        // Actions
        newMenu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        newMenu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        newMenu.addItem(quitItem)

        menu = newMenu
    }

    /// Create a menu item for a pull request with commit info and check status
    private func createPRMenuItem(prInfo: PRDisplayInfo) -> NSMenuItem {
        let pr = prInfo.pr

        // Build check status string
        let checkStatusStr = prInfo.checkStatus?.displayString ?? ""
        let checkStatusSuffix = checkStatusStr.isEmpty ? "" : "  \(checkStatusStr)"

        // Build attributed title with PR title bold, commit message below in gray
        let titleText = "  #\(pr.number): \(pr.title)\(checkStatusSuffix)\n"
        let commitText = "       \(prInfo.lastCommitMessage ?? "Loading...")"

        let fullText = NSMutableAttributedString()

        // PR title in bold
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        fullText.append(NSAttributedString(string: titleText, attributes: titleAttrs))

        // Commit message in gray, smaller
        let commitAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        fullText.append(NSAttributedString(string: commitText, attributes: commitAttrs))

        let item = NSMenuItem(title: "", action: #selector(prClicked(_:)), keyEquivalent: "")
        item.attributedTitle = fullText
        item.target = self
        item.representedObject = pr

        // Build tooltip with check status details
        var tooltip = "\(pr.title)\n\nLast commit: \(prInfo.lastCommitMessage ?? "Unknown")"
        if let status = prInfo.checkStatus, status.totalCount > 0 {
            tooltip += "\n\nChecks: \(status.passedCount)/\(status.totalCount) passed"
            if status.failedCount > 0 {
                tooltip += ", \(status.failedCount) failed"
            }
            if status.pendingCount > 0 {
                tooltip += ", \(status.pendingCount) pending"
            }
        }
        item.toolTip = tooltip
        return item
    }

    /// Truncate a string to a maximum length
    private func truncate(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        }
        return String(string.prefix(maxLength - 3)) + "..."
    }

    // MARK: - Menu Actions

    @objc private func prClicked(_ sender: NSMenuItem) {
        guard let pr = sender.representedObject as? PullRequest else { return }
        NotificationCenter.default.post(
            name: .prSelected,
            object: nil,
            userInfo: ["pr": pr]
        )
    }

    @objc private func refreshClicked() {
        NotificationCenter.default.post(name: .refreshRequested, object: nil)
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Data Updates

    /// Update the pull requests displayed in the menu
    public func updatePullRequests(_ prs: [String: [PRDisplayInfo]]) {
        pullRequests = prs
        rebuildMenu()

        // Update badge count
        let totalCount = prs.values.reduce(0) { $0 + $1.count }
        updateBadge(count: totalCount)
    }

    /// Convenience method to update with plain PRs (will show "Loading..." for commits)
    public func updatePullRequestsSimple(_ prs: [String: [PullRequest]]) {
        var displayInfos: [String: [PRDisplayInfo]] = [:]
        for (repo, prList) in prs {
            displayInfos[repo] = prList.map { PRDisplayInfo(pr: $0) }
        }
        updatePullRequests(displayInfos)
    }

    /// Update the commit message for a specific PR
    public func updateCommitMessage(forPR prNumber: Int, inRepo repo: String, message: String) {
        guard var prInfos = pullRequests[repo] else { return }
        if let index = prInfos.firstIndex(where: { $0.pr.number == prNumber }) {
            prInfos[index].lastCommitMessage = message
            pullRequests[repo] = prInfos
            rebuildMenu()
        }
    }

    /// Update the check status for a specific PR
    public func updateCheckStatus(forPR prNumber: Int, inRepo repo: String, status: CheckStatus, sha: String) {
        guard var prInfos = pullRequests[repo] else { return }
        if let index = prInfos.firstIndex(where: { $0.pr.number == prNumber }) {
            prInfos[index].checkStatus = status
            prInfos[index].lastCheckedSHA = sha
            pullRequests[repo] = prInfos
            rebuildMenu()
        }
    }

    /// Get all PRs that have pending checks (need polling)
    public func getPRsWithPendingChecks() -> [(repo: String, pr: PullRequest, sha: String)] {
        var result: [(repo: String, pr: PullRequest, sha: String)] = []
        for (repo, prInfos) in pullRequests {
            for prInfo in prInfos {
                if let status = prInfo.checkStatus, status.isRunning {
                    result.append((repo: repo, pr: prInfo.pr, sha: prInfo.pr.head.sha))
                }
            }
        }
        return result
    }

    /// Get all PRs that need check status fetched (no status yet or SHA changed)
    public func getPRsNeedingCheckStatus() -> [(repo: String, pr: PullRequest)] {
        var result: [(repo: String, pr: PullRequest)] = []
        for (repo, prInfos) in pullRequests {
            for prInfo in prInfos {
                // Need to fetch if no status or if SHA changed (new commits)
                if prInfo.checkStatus == nil || prInfo.lastCheckedSHA != prInfo.pr.head.sha {
                    result.append((repo: repo, pr: prInfo.pr))
                }
            }
        }
        return result
    }

    /// Clear all pull requests
    public func clearPullRequests() {
        pullRequests = [:]
        rebuildMenu()
        updateBadge(count: 0)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when a PR is selected from the menu
    static let prSelected = Notification.Name("PRReviewSystem.prSelected")

    /// Posted when refresh is requested
    static let refreshRequested = Notification.Name("PRReviewSystem.refreshRequested")
}
