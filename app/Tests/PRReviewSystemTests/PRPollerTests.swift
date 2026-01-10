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

// MARK: - PRPoller Behavior Tests

@Suite("PRPoller Behavior Tests")
struct PRPollerBehaviorTests {

    /// Create a test config
    private func makeConfig(
        repos: [String] = ["owner/repo"],
        username: String = "testuser",
        pollInterval: Int = 60
    ) -> Config {
        Config(
            githubToken: "test-token",
            githubUsername: username,
            repos: repos,
            tokens: [:],
            cloneRoot: "/tmp/test",
            pollIntervalSeconds: pollInterval,
            ghosttyPath: "/Applications/Ghostty.app",
            nvimPath: "/opt/homebrew/bin/nvim",
            notifications: NotificationConfig()
        )
    }

    /// Helper to create a test PullRequest by decoding JSON
    private func makePullRequest(number: Int, user: String = "otheruser", sha: String = "abc123") throws -> PullRequest {
        let json = """
        {
            "id": \(number),
            "number": \(number),
            "title": "Test PR #\(number)",
            "body": "Test body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/\(number)",
            "user": {
                "id": 1,
                "login": "\(user)",
                "avatar_url": "https://example.com/avatar.png"
            },
            "head": {
                "ref": "feature-branch",
                "sha": "\(sha)"
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

    @Test("startPolling sets isPolling to true")
    func startPollingSetsIsPolling() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        // Need to handle the fact that startPolling triggers an immediate poll
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: "[]")
        }

        poller.startPolling { _ in }

        // Give time for async to kick in
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(poller.isPolling == true)

        poller.stopPolling()
    }

    @Test("stopPolling sets isPolling to false")
    func stopPollingSetsIsPollingFalse() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: "[]")
        }

        poller.startPolling { _ in }
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(poller.isPolling == true)

        poller.stopPolling()

        // Give time for stop to process
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(poller.isPolling == false)
    }

    @Test("startPolling ignores duplicate start calls")
    func startPollingIgnoresDuplicates() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        var callCount = 0

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            return MockURLProtocol.successResponse(for: request, jsonString: "[]")
        }

        poller.startPolling { _ in }
        poller.startPolling { _ in } // Should be ignored
        poller.startPolling { _ in } // Should be ignored

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should only poll once on start
        #expect(callCount == 1)

        poller.stopPolling()
    }

    @Test("pollNow triggers immediate poll")
    func pollNowTriggersImmediatePoll() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        var callCount = 0

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            return MockURLProtocol.successResponse(for: request, jsonString: "[]")
        }

        await poller.pollNow()
        await poller.pollNow()

        #expect(callCount == 2)
    }

    @Test("Poll detects new PRs")
    func pollDetectsNewPRs() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        let prJson = """
        [{
            "id": 1,
            "number": 42,
            "title": "New PR",
            "body": "Body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/42",
            "user": {"id": 1, "login": "otheruser", "avatar_url": null},
            "head": {"ref": "feature", "sha": "abc123"},
            "base": {"ref": "main", "sha": "def456"},
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }]
        """

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: prJson)
        }

        var detectedChanges: [PRPoller.PRChange] = []
        poller.startPolling { changes in
            detectedChanges = changes
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(detectedChanges.count == 1)
        if let change = detectedChanges.first {
            #expect(change.pr.number == 42)
            if case .newPR = change.changeType {
                // Expected
            } else {
                Issue.record("Expected newPR change type")
            }
        }

        poller.stopPolling()
    }

    @Test("Poll detects new commits")
    func pollDetectsNewCommits() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        var pollCount = 0
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            pollCount += 1
            let sha = pollCount == 1 ? "abc123" : "xyz789" // Different SHA on second poll
            let prJson = """
            [{
                "id": 1,
                "number": 42,
                "title": "PR",
                "body": "Body",
                "state": "open",
                "html_url": "https://github.com/owner/repo/pull/42",
                "user": {"id": 1, "login": "otheruser", "avatar_url": null},
                "head": {"ref": "feature", "sha": "\(sha)"},
                "base": {"ref": "main", "sha": "def456"},
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-01-01T00:00:00Z"
            }]
            """
            return MockURLProtocol.successResponse(for: request, jsonString: prJson)
        }

        var allChanges: [[PRPoller.PRChange]] = []
        poller.startPolling { changes in
            allChanges.append(changes)
        }

        // Wait for first poll
        try await Task.sleep(nanoseconds: 200_000_000)

        // Manually poll again to detect changes
        await poller.pollNow()

        try await Task.sleep(nanoseconds: 100_000_000)

        // First poll should detect newPR, second should detect newCommits
        #expect(allChanges.count >= 2)
        if allChanges.count >= 2 {
            // Second poll should show new commits
            let secondPollChanges = allChanges[1]
            if let change = secondPollChanges.first {
                if case let .newCommits(oldSHA, newSHA) = change.changeType {
                    #expect(oldSHA == "abc123")
                    #expect(newSHA == "xyz789")
                } else {
                    Issue.record("Expected newCommits change type")
                }
            }
        }

        poller.stopPolling()
    }

    @Test("Poll filters out own PRs")
    func pollFiltersOwnPRs() async throws {
        let config = makeConfig(username: "myuser")
        let poller = PRPoller(config: config)

        // PR is authored by "myuser", which matches config username
        let prJson = """
        [{
            "id": 1,
            "number": 42,
            "title": "My own PR",
            "body": "Body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/42",
            "user": {"id": 1, "login": "myuser", "avatar_url": null},
            "head": {"ref": "feature", "sha": "abc123"},
            "base": {"ref": "main", "sha": "def456"},
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }]
        """

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: prJson)
        }

        var detectedChanges: [PRPoller.PRChange] = []
        poller.startPolling { changes in
            detectedChanges = changes
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should be empty because PR author matches username
        #expect(detectedChanges.isEmpty)

        poller.stopPolling()
    }

    @Test("clearState resets detected changes tracking")
    func clearStateResetsTracking() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        let prJson = """
        [{
            "id": 1,
            "number": 42,
            "title": "PR",
            "body": "Body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/42",
            "user": {"id": 1, "login": "otheruser", "avatar_url": null},
            "head": {"ref": "feature", "sha": "abc123"},
            "base": {"ref": "main", "sha": "def456"},
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }]
        """

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: prJson)
        }

        var changeCount = 0
        poller.startPolling { changes in
            changeCount += changes.count
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should have detected 1 new PR
        #expect(changeCount == 1)

        // Clear state
        poller.clearState()

        // Poll again - should detect same PR as new again
        await poller.pollNow()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Should have detected it again after clear
        #expect(changeCount == 2)

        poller.stopPolling()
    }

    @Test("Poll continues with other repos on API error")
    func pollContinuesOnError() async throws {
        let config = makeConfig(repos: ["owner/repo1", "owner/repo2"])
        let poller = PRPoller(config: config)

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("repo1") == true {
                // First repo fails
                return MockURLProtocol.errorResponse(for: request, statusCode: 500, message: "Server error")
            } else {
                // Second repo succeeds
                let prJson = """
                [{
                    "id": 1,
                    "number": 42,
                    "title": "PR from repo2",
                    "body": "Body",
                    "state": "open",
                    "html_url": "https://github.com/owner/repo2/pull/42",
                    "user": {"id": 1, "login": "otheruser", "avatar_url": null},
                    "head": {"ref": "feature", "sha": "abc123"},
                    "base": {"ref": "main", "sha": "def456"},
                    "created_at": "2026-01-01T00:00:00Z",
                    "updated_at": "2026-01-01T00:00:00Z"
                }]
                """
                return MockURLProtocol.successResponse(for: request, jsonString: prJson)
            }
        }

        var detectedChanges: [PRPoller.PRChange] = []
        poller.startPolling { changes in
            detectedChanges = changes
        }

        try await Task.sleep(nanoseconds: 300_000_000)

        // Should still detect PR from repo2 despite repo1 error
        #expect(detectedChanges.count == 1)
        if let change = detectedChanges.first {
            #expect(change.repo == "owner/repo2")
        }

        poller.stopPolling()
    }

    @Test("Poll handles empty repos config")
    func pollHandlesEmptyReposConfig() async throws {
        // When repos is empty, poller should try to discover repos
        // But since we're mocking, it won't find any
        let config = makeConfig(repos: [])
        let poller = PRPoller(config: config)

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            // Return empty repos for discovery
            if request.url?.path.contains("/user/repos") == true {
                return MockURLProtocol.successResponse(for: request, jsonString: "[]")
            }
            return MockURLProtocol.successResponse(for: request, jsonString: "[]")
        }

        var detectedChanges: [PRPoller.PRChange] = []
        poller.startPolling { changes in
            detectedChanges = changes
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should handle gracefully with no changes
        #expect(detectedChanges.isEmpty)

        poller.stopPolling()
    }
}

// MARK: - PRPoller Edge Case Tests

@Suite("PRPoller Edge Case Tests")
struct PRPollerEdgeCaseTests {

    private func makeConfig(repos: [String] = ["owner/repo"]) -> Config {
        Config(
            githubToken: "test-token",
            githubUsername: "testuser",
            repos: repos,
            tokens: [:],
            cloneRoot: "/tmp/test",
            pollIntervalSeconds: 60,
            ghosttyPath: "/Applications/Ghostty.app",
            nvimPath: "/opt/homebrew/bin/nvim",
            notifications: NotificationConfig()
        )
    }

    @Test("Handles rapid start/stop cycles")
    func rapidStartStopCycles() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: "[]")
        }

        // Rapid start/stop
        for _ in 0 ..< 5 {
            poller.startPolling { _ in }
            poller.stopPolling()
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Should end up not polling
        #expect(poller.isPolling == false)
    }

    @Test("Handles network timeout during poll")
    func handlesNetworkTimeout() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            throw MockURLProtocol.networkError(code: NSURLErrorTimedOut)
        }

        var callbackCalled = false
        poller.startPolling { changes in
            callbackCalled = changes.isEmpty
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should not crash, callback may or may not be called with empty
        #expect(poller.isPolling == true)

        poller.stopPolling()
    }

    @Test("Handles malformed JSON response")
    func handlesMalformedJSON() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: "{ not valid json }")
        }

        var detectedChanges: [PRPoller.PRChange] = []
        poller.startPolling { changes in
            detectedChanges = changes
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should handle gracefully with no changes
        #expect(detectedChanges.isEmpty)
        #expect(poller.isPolling == true)

        poller.stopPolling()
    }

    @Test("Handles PR with very long title")
    func handlesPRWithLongTitle() async throws {
        let config = makeConfig()
        let poller = PRPoller(config: config)

        let longTitle = String(repeating: "A", count: 1000)
        let prJson = """
        [{
            "id": 1,
            "number": 42,
            "title": "\(longTitle)",
            "body": "Body",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/42",
            "user": {"id": 1, "login": "otheruser", "avatar_url": null},
            "head": {"ref": "feature", "sha": "abc123"},
            "base": {"ref": "main", "sha": "def456"},
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }]
        """

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: prJson)
        }

        var detectedChanges: [PRPoller.PRChange] = []
        poller.startPolling { changes in
            detectedChanges = changes
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(detectedChanges.count == 1)
        #expect(detectedChanges.first?.pr.title == longTitle)

        poller.stopPolling()
    }
}
