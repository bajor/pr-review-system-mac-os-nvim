import Foundation
import Testing
@testable import PRReviewSystem

@Suite("PRPoller Tests")
struct PRPollerTests {

    /// Create a test config
    private func makeConfig() -> Config {
        Config(
            githubToken: "test-token",
            githubUsername: "testuser",
            repos: ["owner/repo"],
            tokens: [:],
            cloneRoot: "/tmp/test",
            pollIntervalSeconds: 60,
            ghosttyPath: "/Applications/Ghostty.app",
            nvimPath: "/opt/homebrew/bin/nvim",
            notifications: NotificationConfig()
        )
    }

    @Test("Can be initialized")
    func initialization() {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        #expect(poller.isPolling == false)
    }

    @Test("isPolling is initially false")
    func initialPollingState() {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        #expect(poller.isPolling == false)
    }

    @Test("clearState removes cached state")
    func clearState() {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        // This should not throw
        poller.clearState()
        #expect(poller.isPolling == false)
    }

    @Test("stopPolling can be called when not polling")
    func stopPollingWhenNotPolling() {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        // Should not throw
        poller.stopPolling()
        #expect(poller.isPolling == false)
    }
}

@Suite("PRPoller.PRChange Tests")
struct PRPollerPRChangeTests {

    @Test("PRChange equality for newPR")
    func prChangeNewPREquality() throws {
        let pr = try makePullRequest(number: 1)
        let change1 = PRPoller.PRChange(pr: pr, repo: "owner/repo", changeType: .newPR)
        let change2 = PRPoller.PRChange(pr: pr, repo: "owner/repo", changeType: .newPR)

        #expect(change1 == change2)
    }

    @Test("PRChange equality for newCommits")
    func prChangeNewCommitsEquality() throws {
        let pr = try makePullRequest(number: 1)
        let change1 = PRPoller.PRChange(pr: pr, repo: "owner/repo", changeType: .newCommits(oldSHA: "abc", newSHA: "def"))
        let change2 = PRPoller.PRChange(pr: pr, repo: "owner/repo", changeType: .newCommits(oldSHA: "abc", newSHA: "def"))

        #expect(change1 == change2)
    }

    @Test("PRChange inequality for different changeType")
    func prChangeInequalityDifferentType() throws {
        let pr = try makePullRequest(number: 1)
        let change1 = PRPoller.PRChange(pr: pr, repo: "owner/repo", changeType: .newPR)
        let change2 = PRPoller.PRChange(pr: pr, repo: "owner/repo", changeType: .newComments(count: 5))

        #expect(change1 != change2)
    }

    @Test("PRChange inequality for different repo")
    func prChangeInequalityDifferentRepo() throws {
        let pr = try makePullRequest(number: 1)
        let change1 = PRPoller.PRChange(pr: pr, repo: "owner/repo1", changeType: .newPR)
        let change2 = PRPoller.PRChange(pr: pr, repo: "owner/repo2", changeType: .newPR)

        #expect(change1 != change2)
    }

    @Test("ChangeType newComments stores count")
    func changeTypeNewCommentsCount() {
        let changeType = PRPoller.PRChange.ChangeType.newComments(count: 10)
        if case let .newComments(count) = changeType {
            #expect(count == 10)
        } else {
            Issue.record("Expected newComments")
        }
    }

    @Test("ChangeType statusChanged stores from and to")
    func changeTypeStatusChanged() {
        let changeType = PRPoller.PRChange.ChangeType.statusChanged(from: "open", to: "merged")
        if case let .statusChanged(from, to) = changeType {
            #expect(from == "open")
            #expect(to == "merged")
        } else {
            Issue.record("Expected statusChanged")
        }
    }

    /// Helper to create a test PullRequest by decoding JSON
    private func makePullRequest(number: Int) throws -> PullRequest {
        let json = """
        {
            "id": \(number),
            "number": \(number),
            "title": "Test PR",
            "body": "Test body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/\(number)",
            "user": {
                "id": 1,
                "login": "testuser",
                "avatar_url": "https://example.com/avatar.png"
            },
            "head": {
                "ref": "feature-branch",
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
