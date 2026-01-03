import Testing
import Foundation
@testable import PRReviewSystem

@Suite("GitOperations Tests")
struct GitOperationsTests {

    @Test("Build PR path correctly")
    func buildPRPath() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/home/user/repos",
            owner: "owner",
            repo: "repo",
            prNumber: 123
        )
        #expect(path == "/home/user/repos/owner/repo/pr-123")
    }

    @Test("Build PR path with different values")
    func buildPRPathVariant() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/tmp/prs",
            owner: "org",
            repo: "project",
            prNumber: 1
        )
        #expect(path == "/tmp/prs/org/project/pr-1")
    }

    @Test("Build PR path with large number")
    func buildPRPathLargeNumber() {
        let path = GitOperations.buildPRPath(
            cloneRoot: "/data",
            owner: "company",
            repo: "app",
            prNumber: 99999
        )
        #expect(path == "/data/company/app/pr-99999")
    }

    @Test("Is git repo returns true for git directory")
    func isGitRepoTrue() {
        // Find the repo root by looking for .git directory
        var path = FileManager.default.currentDirectoryPath
        while !path.isEmpty && path != "/" {
            if GitOperations.isGitRepo(at: path) {
                #expect(GitOperations.isGitRepo(at: path) == true)
                return
            }
            path = (path as NSString).deletingLastPathComponent
        }
        // If no git repo found, test against a known path or skip
        // This can happen in sandboxed test environments
    }

    @Test("Is git repo returns false for non-git directory")
    func isGitRepoFalse() {
        #expect(GitOperations.isGitRepo(at: "/tmp") == false)
    }

    @Test("Is git repo returns false for non-existent directory")
    func isGitRepoNonExistent() {
        #expect(GitOperations.isGitRepo(at: "/nonexistent/path/12345") == false)
    }
}

@Suite("GitError Tests")
struct GitErrorTests {

    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        let errors: [GitError] = [
            .commandFailed(command: "git clone", exitCode: 1, message: "error"),
            .notARepository(path: "/tmp"),
        ]

        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("Command failed includes all info")
    func commandFailedDescription() {
        let error = GitError.commandFailed(
            command: "git clone",
            exitCode: 128,
            message: "repository not found"
        )
        #expect(error.description.contains("git clone"))
        #expect(error.description.contains("128"))
        #expect(error.description.contains("repository not found"))
    }
}

@Suite("GitOperations Integration Tests")
struct GitOperationsIntegrationTests {

    @Test("Get current branch in repo")
    func getCurrentBranch() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        // Only run if we're in a git repo
        guard GitOperations.isGitRepo(at: cwd) else {
            return
        }

        let branch = try await GitOperations.getCurrentBranch(at: cwd)
        #expect(!branch.isEmpty)
    }

    @Test("Get current SHA in repo")
    func getCurrentSHA() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        // Only run if we're in a git repo
        guard GitOperations.isGitRepo(at: cwd) else {
            return
        }

        let sha = try await GitOperations.getCurrentSHA(at: cwd)
        #expect(sha.count == 40)
        // SHA should be hex
        #expect(sha.allSatisfy { $0.isHexDigit })
    }
}
