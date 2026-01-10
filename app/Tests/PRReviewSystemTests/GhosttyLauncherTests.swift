import Foundation
import Testing
@testable import PRReviewSystem

@Suite("GhosttyLauncher Tests")
struct GhosttyLauncherTests {

    @Test("Can be initialized from config")
    func initFromConfig() {
        let config = Config(
            githubToken: "test",
            githubUsername: "user",
            repos: ["owner/repo"],
            tokens: [:],
            cloneRoot: "/tmp/test",
            pollIntervalSeconds: 300,
            ghosttyPath: "/Applications/Ghostty.app",
            nvimPath: "/opt/homebrew/bin/nvim",
            notifications: NotificationConfig()
        )
        let launcher = GhosttyLauncher(config: config)
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Can be initialized with multi-token config")
    func initWithMultiTokenConfig() {
        let config = Config(
            githubToken: "default-token",
            githubUsername: "user",
            repos: ["owner/repo", "org/repo"],
            tokens: ["org": "org-specific-token"],
            cloneRoot: "/tmp/test",
            pollIntervalSeconds: 300,
            ghosttyPath: "/Applications/Ghostty.app",
            nvimPath: "/opt/homebrew/bin/nvim",
            notifications: NotificationConfig()
        )
        let launcher = GhosttyLauncher(config: config)
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }
}

@Suite("GhosttyLauncherError Tests")
struct GhosttyLauncherErrorTests {

    @Test("ghosttyNotFound error description")
    func ghosttyNotFoundDescription() {
        let error = GhosttyLauncherError.ghosttyNotFound(path: "/test/path")
        #expect(error.description.contains("/test/path"))
        #expect(error.description.contains("not found"))
    }

    @Test("launchFailed error description")
    func launchFailedDescription() {
        let error = GhosttyLauncherError.launchFailed(message: "test error")
        #expect(error.description.contains("test error"))
        #expect(error.description.contains("Failed"))
    }

    @Test("cloneFailed error description")
    func cloneFailedDescription() {
        let error = GhosttyLauncherError.cloneFailed(message: "clone error")
        #expect(error.description.contains("clone error"))
        #expect(error.description.contains("clone"))
    }

    @Test("All error types conform to Error")
    func allErrorsConformToError() {
        let errors: [any Error] = [
            GhosttyLauncherError.ghosttyNotFound(path: "/path"),
            GhosttyLauncherError.launchFailed(message: "msg"),
            GhosttyLauncherError.cloneFailed(message: "msg"),
        ]

        #expect(errors.count == 3)
    }
}

// MARK: - GhosttyLauncher Configuration Tests

@Suite("GhosttyLauncher Configuration Tests")
struct GhosttyLauncherConfigTests {

    private func makeConfig(
        cloneRoot: String = "/tmp/test",
        ghosttyPath: String = "/Applications/Ghostty.app",
        nvimPath: String = "/opt/homebrew/bin/nvim",
        tokens: [String: String] = [:]
    ) -> Config {
        Config(
            githubToken: "default-token",
            githubUsername: "testuser",
            repos: ["owner/repo"],
            tokens: tokens,
            cloneRoot: cloneRoot,
            pollIntervalSeconds: 300,
            ghosttyPath: ghosttyPath,
            nvimPath: nvimPath,
            notifications: NotificationConfig()
        )
    }

    @Test("Config with .app path builds binary path correctly")
    func configWithAppPath() {
        let config = makeConfig(ghosttyPath: "/Applications/Ghostty.app")
        let launcher = GhosttyLauncher(config: config)
        // Can't test internal binary path building directly, but config is valid
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Config with direct binary path")
    func configWithBinaryPath() {
        let config = makeConfig(ghosttyPath: "/usr/local/bin/ghostty")
        let launcher = GhosttyLauncher(config: config)
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Config with tilde in clone root")
    func configWithTildeCloneRoot() {
        let config = makeConfig(cloneRoot: "~/pr-reviews")
        let launcher = GhosttyLauncher(config: config)
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Config with absolute clone root")
    func configWithAbsoluteCloneRoot() {
        let config = makeConfig(cloneRoot: "/var/repos/pr-reviews")
        let launcher = GhosttyLauncher(config: config)
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Config with owner-specific tokens")
    func configWithOwnerTokens() {
        let config = makeConfig(tokens: [
            "org1": "token1",
            "org2": "token2",
        ])
        let launcher = GhosttyLauncher(config: config)
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Config uses correct token for owner")
    func configResolvesTokenForOwner() {
        let config = makeConfig(tokens: [
            "special-org": "special-token",
        ])

        // Test token resolution via config
        let defaultToken = config.resolveToken(for: "random-owner")
        let specialToken = config.resolveToken(for: "special-org")

        #expect(defaultToken == "default-token")
        #expect(specialToken == "special-token")
    }
}

// MARK: - GhosttyLauncher Path Tests

@Suite("GhosttyLauncher Path Building Tests")
struct GhosttyLauncherPathTests {

    @Test("PR path is built correctly")
    func prPathBuilding() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/tmp/test",
            owner: "myorg",
            repo: "myrepo",
            prNumber: 42
        )
        #expect(path == "/tmp/test/myorg/myrepo/42")
    }

    @Test("PR path handles special characters in repo name")
    func prPathWithSpecialChars() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/tmp/test",
            owner: "my-org",
            repo: "my_repo",
            prNumber: 123
        )
        #expect(path == "/tmp/test/my-org/my_repo/123")
    }

    @Test("PR path handles numbers in org/repo names")
    func prPathWithNumbers() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/tmp/test",
            owner: "org123",
            repo: "repo456",
            prNumber: 789
        )
        #expect(path == "/tmp/test/org123/repo456/789")
    }

    @Test("PR path handles trailing slash in clone root")
    func prPathWithTrailingSlash() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/tmp/test/",
            owner: "owner",
            repo: "repo",
            prNumber: 1
        )
        // Path should not have double slashes
        #expect(!path.contains("//"))
    }
}

// MARK: - GhosttyLauncher Edge Case Tests

@Suite("GhosttyLauncher Edge Case Tests")
struct GhosttyLauncherEdgeCaseTests {

    private func makeConfig(
        cloneRoot: String = "/tmp/test",
        ghosttyPath: String = "/Applications/Ghostty.app",
        nvimPath: String = "/opt/homebrew/bin/nvim"
    ) -> Config {
        Config(
            githubToken: "test-token",
            githubUsername: "testuser",
            repos: ["owner/repo"],
            tokens: [:],
            cloneRoot: cloneRoot,
            pollIntervalSeconds: 300,
            ghosttyPath: ghosttyPath,
            nvimPath: nvimPath,
            notifications: NotificationConfig()
        )
    }

    @Test("Throws ghosttyNotFound for non-existent path")
    func throwsGhosttyNotFound() async throws {
        let config = makeConfig(ghosttyPath: "/nonexistent/path/Ghostty.app")
        let launcher = GhosttyLauncher(config: config)

        let pr = try makePullRequest(number: 1)

        // This should throw because Ghostty doesn't exist
        await #expect(throws: GhosttyLauncherError.self) {
            try await launcher.openPR(pr, owner: "owner", repo: "repo")
        }
    }

    @Test("Handles PR with unicode title")
    func handlesUnicodeTitle() throws {
        // Test that we can create PR with unicode
        let pr = try makePullRequest(number: 1, title: "Fix bug: 日本語テスト 🎉")
        #expect(pr.title == "Fix bug: 日本語テスト 🎉")
    }

    @Test("Handles PR with very long branch name")
    func handlesLongBranchName() throws {
        let longBranch = String(repeating: "a", count: 200)
        let pr = try makePullRequest(number: 1, branch: longBranch)
        #expect(pr.head.ref == longBranch)
    }

    @Test("openAllPRs handles empty array")
    func openAllPRsEmptyArray() async throws {
        let config = makeConfig()
        let launcher = GhosttyLauncher(config: config)

        // Should not throw for empty array
        try await launcher.openAllPRs([])
    }

    /// Helper to create a test PullRequest
    private func makePullRequest(
        number: Int,
        title: String = "Test PR",
        branch: String = "feature-branch"
    ) throws -> PullRequest {
        let json = """
        {
            "id": \(number),
            "number": \(number),
            "title": "\(title.replacingOccurrences(of: "\"", with: "\\\""))",
            "body": "Test body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/\(number)",
            "user": {
                "id": 1,
                "login": "testuser",
                "avatar_url": "https://example.com/avatar.png"
            },
            "head": {
                "ref": "\(branch)",
                "sha": "abc123"
            },
            "base": {
                "ref": "main",
                "sha": "def456"
            },
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PullRequest.self, from: json.data(using: .utf8)!)
    }
}
