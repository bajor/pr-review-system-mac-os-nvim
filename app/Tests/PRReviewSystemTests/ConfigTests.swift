import Testing
import Foundation
@testable import PRReviewSystem

@Suite("Config Tests")
struct ConfigTests {

    @Test("Defaults have all required fields")
    func defaultsHaveAllFields() {
        let defaults = Config.defaults
        #expect(defaults.githubToken.isEmpty)
        #expect(defaults.githubUsername.isEmpty)
        #expect(defaults.repos.isEmpty)
        #expect(!defaults.cloneRoot.isEmpty)
        #expect(defaults.pollIntervalSeconds == 300)
        #expect(!defaults.ghosttyPath.isEmpty)
        #expect(!defaults.nvimPath.isEmpty)
    }

    @Test("NotificationConfig defaults")
    func notificationDefaults() {
        let defaults = NotificationConfig.defaults
        #expect(defaults.newCommits == true)
        #expect(defaults.newComments == true)
        #expect(defaults.sound == true)
    }
}

@Suite("ConfigLoader Tests", .serialized)
struct ConfigLoaderTests {

    @Test("Returns error when config file does not exist")
    func fileNotFound() {
        let path = "/nonexistent/path/config.json"
        #expect(throws: ConfigError.fileNotFound(path: path)) {
            try ConfigLoader.load(from: path)
        }
    }

    @Test("Returns error for invalid JSON")
    func invalidJSON() throws {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try "{ invalid json }".write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        #expect {
            try ConfigLoader.load(from: tmpFile.path)
        } throws: { error in
            if case ConfigError.invalidJSON = error {
                return true
            }
            return false
        }
    }

    @Test("Returns error when GITHUB_TOKEN_PR_REVIEW_SYSTEM env var is missing")
    func missingGithubToken() throws {
        // Temporarily unset the env var if it exists
        let originalValue = ProcessInfo.processInfo.environment["GITHUB_TOKEN_PR_REVIEW_SYSTEM"]
        unsetenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM")
        defer {
            if let original = originalValue {
                setenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM", original, 1)
            }
        }

        let json = """
        {
            "github_username": "user",
            "repos": ["owner/repo"]
        }
        """
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        #expect(throws: ConfigError.missingRequiredField(name: "github_token (set GITHUB_TOKEN_PR_REVIEW_SYSTEM env var or add to config)")) {
            try ConfigLoader.load(from: tmpFile.path)
        }
    }

    @Test("Returns error when github_username is missing")
    func missingGithubUsername() throws {
        // Set env var for this test
        setenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM", "ghp_test", 1)
        defer { unsetenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM") }

        let json = """
        {
            "repos": ["owner/repo"]
        }
        """
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        #expect(throws: ConfigError.missingRequiredField(name: "github_username")) {
            try ConfigLoader.load(from: tmpFile.path)
        }
    }

    @Test("Returns error when repos is empty")
    func emptyRepos() throws {
        // Set env var for this test
        setenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM", "ghp_test", 1)
        defer { unsetenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM") }

        let json = """
        {
            "github_username": "user",
            "repos": []
        }
        """
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        #expect(throws: ConfigError.emptyRepos) {
            try ConfigLoader.load(from: tmpFile.path)
        }
    }

    @Test("Returns error for invalid repo format")
    func invalidRepoFormat() throws {
        // Set env var for this test
        setenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM", "ghp_test", 1)
        defer { unsetenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM") }

        let json = """
        {
            "github_username": "user",
            "repos": ["invalid"]
        }
        """
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        #expect(throws: ConfigError.invalidRepoFormat(repo: "invalid")) {
            try ConfigLoader.load(from: tmpFile.path)
        }
    }

    @Test("Loads valid config successfully")
    func loadValidConfig() throws {
        // Set env var for this test
        setenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM", "ghp_test123", 1)
        defer { unsetenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM") }

        let json = """
        {
            "github_username": "testuser",
            "repos": ["owner/repo1", "owner/repo2"],
            "clone_root": "/tmp/test/repos"
        }
        """
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let config = try ConfigLoader.load(from: tmpFile.path)
        #expect(config.githubToken == "ghp_test123")
        #expect(config.githubUsername == "testuser")
        #expect(config.repos.count == 2)
        #expect(config.cloneRoot == "/tmp/test/repos")
    }

    @Test("Merges with defaults for missing optional fields")
    func mergeWithDefaults() throws {
        // Set env var for this test
        setenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM", "ghp_test123", 1)
        defer { unsetenv("GITHUB_TOKEN_PR_REVIEW_SYSTEM") }

        let json = """
        {
            "github_username": "testuser",
            "repos": ["owner/repo"]
        }
        """
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let config = try ConfigLoader.load(from: tmpFile.path)
        // Should have default values
        #expect(config.pollIntervalSeconds == 300)
        #expect(config.ghosttyPath == "/Applications/Ghostty.app")
        #expect(config.notifications.newCommits == true)
    }

    @Test("Expands tilde in paths")
    func expandsTildePaths() {
        let expanded = ConfigLoader.expandPath("~/test/path")
        #expect(!expanded.hasPrefix("~"))
        #expect(expanded.hasPrefix("/"))
    }

    @Test("Validates repo format correctly")
    func validatesRepoFormat() {
        #expect(ConfigLoader.isValidRepoFormat("owner/repo") == true)
        #expect(ConfigLoader.isValidRepoFormat("my-org/my-repo") == true)
        #expect(ConfigLoader.isValidRepoFormat("org_name/repo.name") == true)
        #expect(ConfigLoader.isValidRepoFormat("invalid") == false)
        #expect(ConfigLoader.isValidRepoFormat("a/b/c") == false)
        #expect(ConfigLoader.isValidRepoFormat("") == false)
    }
}

@Suite("ConfigError Tests")
struct ConfigErrorTests {

    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        let errors: [ConfigError] = [
            .fileNotFound(path: "/test/path"),
            .invalidJSON(message: "test error"),
            .missingRequiredField(name: "test_field"),
            .invalidRepoFormat(repo: "invalid"),
            .emptyRepos,
        ]

        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }
}
