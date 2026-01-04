import AppKit
import Foundation

/// Launches Ghostty terminal with Neovim for PR review
public final class GhosttyLauncher {
    // MARK: - Properties

    /// Configuration (used for paths and token resolution)
    private let config: Config

    // MARK: - Initialization

    public init(config: Config) {
        self.config = config
    }

    // MARK: - Public API

    /// Open a pull request in Ghostty + Neovim
    /// - Parameters:
    ///   - pr: The pull request to open
    ///   - owner: Repository owner
    ///   - repo: Repository name
    public func openPR(_ pr: PullRequest, owner: String, repo: String) async throws {
        // Expand clone root (handle ~)
        let cloneRoot = config.cloneRoot
        let expandedCloneRoot: String
        if cloneRoot.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            expandedCloneRoot = home + cloneRoot.dropFirst()
        } else {
            expandedCloneRoot = cloneRoot
        }

        // Build the clone path
        let clonePath = GitOperations.buildPRPath(cloneRoot: expandedCloneRoot, owner: owner, repo: repo, prNumber: pr.number)

        // Ensure the clone directory exists
        let fileManager = FileManager.default
        let cloneURL = URL(fileURLWithPath: clonePath)
        let parentURL = cloneURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: parentURL.path) {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        }

        // Clone or update the repository (with owner-specific token for authentication)
        let token = config.resolveToken(for: owner)
        let repoURL = "https://\(token)@github.com/\(owner)/\(repo).git"
        let branch = pr.head.ref

        if GitOperations.isGitRepo(at: clonePath) {
            // Update existing clone - also update remote URL to include token
            try await GitOperations.setRemoteURL(at: clonePath, url: repoURL)
            try await GitOperations.fetchAndReset(at: clonePath, branch: branch)
        } else {
            // Clone fresh
            try await GitOperations.clone(url: repoURL, to: clonePath, branch: branch)
        }

        // Build the PR URL
        let prURL = pr.htmlUrl

        // Launch Ghostty with Neovim
        try await launchGhostty(withPRURL: prURL, workingDirectory: clonePath)
    }

    /// Open a PR by URL
    /// - Parameter url: The GitHub PR URL
    public func openPRByURL(_ url: String) async throws {
        try await launchGhostty(withPRURL: url, workingDirectory: nil)
    }

    // MARK: - Private Helpers

    /// Launch Ghostty with Neovim configured for PR review
    private func launchGhostty(withPRURL prURL: String, workingDirectory: String?) async throws {
        // Get the Ghostty CLI binary path
        let ghosttyPath = config.ghosttyPath
        let ghosttyBinary: String
        if ghosttyPath.hasSuffix(".app") {
            ghosttyBinary = "\(ghosttyPath)/Contents/MacOS/ghostty"
        } else {
            ghosttyBinary = ghosttyPath
        }

        // Check if Ghostty exists
        guard FileManager.default.fileExists(atPath: ghosttyBinary) else {
            throw GhosttyLauncherError.ghosttyNotFound(path: ghosttyBinary)
        }

        // Build the shell command to execute inside Ghostty
        let nvimPath = config.nvimPath
        let shellCommand: String
        if let dir = workingDirectory {
            // cd to directory and run nvim with PRReview command
            shellCommand = "cd '\(dir)' && \(nvimPath) -c 'PRReview open \(prURL)'"
        } else {
            shellCommand = "\(nvimPath) -c 'PRReview open \(prURL)'"
        }

        // Launch Ghostty using Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghosttyBinary)
        process.arguments = ["-e", "/bin/zsh", "-c", shellCommand]

        do {
            try process.run()
            print("Launched Ghostty with PR: \(prURL)")
        } catch {
            throw GhosttyLauncherError.launchFailed(message: error.localizedDescription)
        }
    }
}

// MARK: - Errors

/// Errors that can occur when launching Ghostty
public enum GhosttyLauncherError: Error, CustomStringConvertible {
    case ghosttyNotFound(path: String)
    case launchFailed(message: String)
    case cloneFailed(message: String)

    public var description: String {
        switch self {
        case let .ghosttyNotFound(path):
            return "Ghostty not found at: \(path)"
        case let .launchFailed(message):
            return "Failed to launch Ghostty: \(message)"
        case let .cloneFailed(message):
            return "Failed to clone repository: \(message)"
        }
    }
}
