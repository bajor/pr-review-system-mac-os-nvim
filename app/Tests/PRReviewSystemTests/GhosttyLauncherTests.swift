import Foundation
import Testing
@testable import PRReviewSystem

@Suite("GhosttyLauncher Tests")
struct GhosttyLauncherTests {

    @Test("Can be initialized with paths")
    func initWithPaths() {
        let launcher = GhosttyLauncher(
            ghosttyPath: "/Applications/Ghostty.app",
            nvimPath: "/opt/homebrew/bin/nvim",
            cloneRoot: "~/.local/share/pr-review/repos",
            githubToken: "ghp_test"
        )
        #expect(type(of: launcher) == GhosttyLauncher.self)
    }

    @Test("Can be initialized from config")
    func initFromConfig() {
        let config = Config(
            githubToken: "test",
            githubUsername: "user",
            repos: ["owner/repo"],
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
}
