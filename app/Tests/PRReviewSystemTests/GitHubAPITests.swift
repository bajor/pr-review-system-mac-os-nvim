import Testing
import Foundation
@testable import PRReviewSystem

@Suite("GitHubAPI Tests")
struct GitHubAPITests {

    @Test("Base URL is correct")
    func baseURL() {
        #expect(GitHubAPI.baseURL == "https://api.github.com")
    }

    @Test("Parse valid PR URL")
    func parseValidPRUrl() {
        let result = GitHubAPI.parsePRUrl("https://github.com/owner/repo/pull/123")
        #expect(result != nil)
        #expect(result?.owner == "owner")
        #expect(result?.repo == "repo")
        #expect(result?.number == 123)
    }

    @Test("Parse PR URL with hyphens and underscores")
    func parsePRUrlWithSpecialChars() {
        let result = GitHubAPI.parsePRUrl("https://github.com/my-org/my_repo/pull/456")
        #expect(result != nil)
        #expect(result?.owner == "my-org")
        #expect(result?.repo == "my_repo")
        #expect(result?.number == 456)
    }

    @Test("Parse PR URL with numbers in name")
    func parsePRUrlWithNumbers() {
        let result = GitHubAPI.parsePRUrl("https://github.com/org123/repo456/pull/789")
        #expect(result != nil)
        #expect(result?.owner == "org123")
        #expect(result?.repo == "repo456")
        #expect(result?.number == 789)
    }

    @Test("Parse PR URL with trailing path")
    func parsePRUrlWithTrailingPath() {
        let result = GitHubAPI.parsePRUrl("https://github.com/owner/repo/pull/123/files")
        #expect(result != nil)
        #expect(result?.owner == "owner")
        #expect(result?.repo == "repo")
        #expect(result?.number == 123)
    }

    @Test("Returns nil for invalid URL")
    func parseInvalidUrl() {
        let result = GitHubAPI.parsePRUrl("https://example.com/not/a/pr")
        #expect(result == nil)
    }

    @Test("Returns nil for GitHub non-PR URL")
    func parseNonPRUrl() {
        let result = GitHubAPI.parsePRUrl("https://github.com/owner/repo/issues/123")
        #expect(result == nil)
    }

    @Test("Returns nil for empty string")
    func parseEmptyString() {
        let result = GitHubAPI.parsePRUrl("")
        #expect(result == nil)
    }
}

@Suite("GitHubAPIError Tests")
struct GitHubAPIErrorTests {

    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        let errors: [GitHubAPIError] = [
            .invalidURL("bad-url"),
            .invalidResponse,
            .httpError(statusCode: 404),
            .apiError(statusCode: 401, message: "Bad credentials"),
            .decodingError("Test error"),
        ]

        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("API error includes status code and message")
    func apiErrorDescription() {
        let error = GitHubAPIError.apiError(statusCode: 401, message: "Bad credentials")
        #expect(error.description.contains("401"))
        #expect(error.description.contains("Bad credentials"))
    }
}

@Suite("Model Decoding Tests")
struct ModelDecodingTests {

    @Test("PullRequest decodes from JSON")
    func decodePullRequest() throws {
        let json = """
        {
            "id": 1,
            "number": 42,
            "title": "Test PR",
            "body": "Description",
            "state": "open",
            "html_url": "https://github.com/owner/repo/pull/42",
            "user": {
                "id": 100,
                "login": "testuser",
                "avatar_url": "https://avatars.githubusercontent.com/u/100"
            },
            "head": {
                "ref": "feature-branch",
                "sha": "abc123",
                "repo": null
            },
            "base": {
                "ref": "main",
                "sha": "def456",
                "repo": null
            },
            "created_at": "2026-01-03T10:00:00Z",
            "updated_at": "2026-01-03T12:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let pr = try decoder.decode(PullRequest.self, from: Data(json.utf8))

        #expect(pr.id == 1)
        #expect(pr.number == 42)
        #expect(pr.title == "Test PR")
        #expect(pr.state == "open")
        #expect(pr.user.login == "testuser")
        #expect(pr.head.ref == "feature-branch")
        #expect(pr.base.ref == "main")
    }

    @Test("PRFile decodes from JSON")
    func decodePRFile() throws {
        let json = """
        {
            "sha": "abc123",
            "filename": "src/main.rs",
            "status": "modified",
            "additions": 10,
            "deletions": 5,
            "changes": 15,
            "patch": "@@ -1,5 +1,10 @@"
        }
        """

        let file = try JSONDecoder().decode(PRFile.self, from: Data(json.utf8))

        #expect(file.sha == "abc123")
        #expect(file.filename == "src/main.rs")
        #expect(file.status == "modified")
        #expect(file.additions == 10)
        #expect(file.deletions == 5)
        #expect(file.patch != nil)
    }

    @Test("PRComment decodes from JSON")
    func decodePRComment() throws {
        let json = """
        {
            "id": 999,
            "body": "This looks good!",
            "user": {
                "id": 100,
                "login": "reviewer",
                "avatar_url": null
            },
            "path": "src/lib.rs",
            "line": 42,
            "side": "RIGHT",
            "commit_id": "abc123",
            "created_at": "2026-01-03T10:00:00Z",
            "updated_at": "2026-01-03T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let comment = try decoder.decode(PRComment.self, from: Data(json.utf8))

        #expect(comment.id == 999)
        #expect(comment.body == "This looks good!")
        #expect(comment.path == "src/lib.rs")
        #expect(comment.line == 42)
        #expect(comment.side == "RIGHT")
    }

    @Test("ReviewEvent encodes correctly")
    func reviewEventEncoding() throws {
        #expect(ReviewEvent.approve.rawValue == "APPROVE")
        #expect(ReviewEvent.requestChanges.rawValue == "REQUEST_CHANGES")
        #expect(ReviewEvent.comment.rawValue == "COMMENT")
    }
}

// MARK: - API Behavior Tests

@Suite("GitHubAPI Behavior Tests")
struct GitHubAPIBehaviorTests {

    init() {
        MockURLProtocol.reset()
    }

    // MARK: - listPRs Tests

    @Test("listPRs returns PRs on success")
    func listPRsSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/repos/owner/repo/pulls")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return MockURLProtocol.successResponse(
                for: request,
                jsonString: MockResponses.pullRequestList
            )
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let prs = try await api.listPRs(owner: "owner", repo: "repo")

        #expect(prs.count == 2)
        #expect(prs[0].number == 42)
        #expect(prs[0].title == "Add new feature")
        #expect(prs[1].number == 43)
    }

    @Test("listPRs returns empty array when no PRs")
    func listPRsEmpty() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: MockResponses.emptyList)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let prs = try await api.listPRs(owner: "owner", repo: "repo")

        #expect(prs.isEmpty)
    }

    @Test("listPRs handles pagination")
    func listPRsPagination() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                // First page with Link header
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: "[{\"id\":1,\"number\":1,\"title\":\"PR 1\",\"body\":\"\",\"state\":\"open\",\"html_url\":\"url\",\"user\":{\"id\":1,\"login\":\"u\",\"avatar_url\":null},\"head\":{\"ref\":\"b\",\"sha\":\"s\",\"repo\":null},\"base\":{\"ref\":\"m\",\"sha\":\"s\",\"repo\":null},\"created_at\":\"2026-01-01T00:00:00Z\",\"updated_at\":\"2026-01-01T00:00:00Z\"}]",
                    linkHeader: "<https://api.github.com/repos/owner/repo/pulls?page=2>; rel=\"next\""
                )
            } else {
                // Second page, no Link header
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: "[{\"id\":2,\"number\":2,\"title\":\"PR 2\",\"body\":\"\",\"state\":\"open\",\"html_url\":\"url\",\"user\":{\"id\":1,\"login\":\"u\",\"avatar_url\":null},\"head\":{\"ref\":\"b\",\"sha\":\"s\",\"repo\":null},\"base\":{\"ref\":\"m\",\"sha\":\"s\",\"repo\":null},\"created_at\":\"2026-01-01T00:00:00Z\",\"updated_at\":\"2026-01-01T00:00:00Z\"}]"
                )
            }
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let prs = try await api.listPRs(owner: "owner", repo: "repo")

        #expect(requestCount == 2)
        #expect(prs.count == 2)
        #expect(prs[0].number == 1)
        #expect(prs[1].number == 2)
    }

    // MARK: - getPR Tests

    @Test("getPR returns PR on success")
    func getPRSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/repos/owner/repo/pulls/42")
            return MockURLProtocol.successResponse(
                for: request,
                jsonString: MockResponses.pullRequest
            )
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let pr = try await api.getPR(owner: "owner", repo: "repo", number: 42)

        #expect(pr.number == 42)
        #expect(pr.title == "Add new feature")
        #expect(pr.head.ref == "feature-branch")
    }

    @Test("getPR throws on 404")
    func getPRNotFound() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.errorResponse(for: request, statusCode: 404, message: "Not Found")
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)

        await #expect(throws: GitHubAPIError.self) {
            try await api.getPR(owner: "owner", repo: "repo", number: 999)
        }
    }

    @Test("getPR throws on 401 unauthorized")
    func getPRUnauthorized() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.errorResponse(for: request, statusCode: 401, message: "Bad credentials")
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "bad-token", session: session)

        await #expect(throws: GitHubAPIError.self) {
            try await api.getPR(owner: "owner", repo: "repo", number: 42)
        }
    }

    // MARK: - getPRFiles Tests

    @Test("getPRFiles returns files on success")
    func getPRFilesSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/repos/owner/repo/pulls/42/files")
            return MockURLProtocol.successResponse(
                for: request,
                jsonString: MockResponses.prFiles
            )
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let files = try await api.getPRFiles(owner: "owner", repo: "repo", number: 42)

        #expect(files.count == 2)
        #expect(files[0].filename == "src/main.swift")
        #expect(files[0].status == "modified")
        #expect(files[1].filename == "src/utils.swift")
        #expect(files[1].status == "added")
    }

    @Test("getPRFiles returns empty array for PR with no changes")
    func getPRFilesEmpty() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: MockResponses.prFilesEmpty)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let files = try await api.getPRFiles(owner: "owner", repo: "repo", number: 42)

        #expect(files.isEmpty)
    }

    // MARK: - getPRComments Tests

    @Test("getPRComments returns comments on success")
    func getPRCommentsSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/repos/owner/repo/pulls/42/comments")
            return MockURLProtocol.successResponse(
                for: request,
                jsonString: MockResponses.prComments
            )
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let comments = try await api.getPRComments(owner: "owner", repo: "repo", number: 42)

        #expect(comments.count == 2)
        #expect(comments[0].body == "This looks good!")
        #expect(comments[0].path == "src/main.swift")
        #expect(comments[1].path == "src/utils.swift")
    }

    @Test("getPRComments returns empty array when no comments")
    func getPRCommentsEmpty() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: MockResponses.prCommentsEmpty)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let comments = try await api.getPRComments(owner: "owner", repo: "repo", number: 42)

        #expect(comments.isEmpty)
    }

    // MARK: - getCheckStatus Tests

    @Test("getCheckStatus returns success when all checks pass")
    func getCheckStatusSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("check-runs") == true {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.checkRunsSuccess
                )
            } else {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.combinedStatusEmpty
                )
            }
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let status = try await api.getCheckStatus(owner: "owner", repo: "repo", ref: "abc123")

        #expect(status.status == .success)
        #expect(status.totalCount == 2)
        #expect(status.passedCount == 2)
        #expect(status.failedCount == 0)
        #expect(status.pendingCount == 0)
    }

    @Test("getCheckStatus returns failure when any check fails")
    func getCheckStatusFailure() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("check-runs") == true {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.checkRunsFailed
                )
            } else {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.combinedStatusEmpty
                )
            }
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let status = try await api.getCheckStatus(owner: "owner", repo: "repo", ref: "abc123")

        #expect(status.status == .failure)
        #expect(status.failedCount == 1)
        #expect(status.passedCount == 1)
    }

    @Test("getCheckStatus returns pending when checks in progress")
    func getCheckStatusPending() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("check-runs") == true {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.checkRunsPending
                )
            } else {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.combinedStatusEmpty
                )
            }
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let status = try await api.getCheckStatus(owner: "owner", repo: "repo", ref: "abc123")

        #expect(status.status == .pending)
        #expect(status.pendingCount == 1)
    }

    @Test("getCheckStatus returns unknown when no checks")
    func getCheckStatusUnknown() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("check-runs") == true {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.checkRunsEmpty
                )
            } else {
                return MockURLProtocol.successResponse(
                    for: request,
                    jsonString: MockResponses.combinedStatusEmpty
                )
            }
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let status = try await api.getCheckStatus(owner: "owner", repo: "repo", ref: "abc123")

        #expect(status.status == .unknown)
        #expect(status.totalCount == 0)
    }

    // MARK: - getLastCommit Tests

    @Test("getLastCommit returns last commit")
    func getLastCommitSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: MockResponses.commits)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let commit = try await api.getLastCommit(owner: "owner", repo: "repo", number: 42)

        #expect(commit != nil)
        #expect(commit?.sha == "def456")
        #expect(commit?.commit.message == "Add feature")
    }

    @Test("getLastCommit returns nil for PR with no commits")
    func getLastCommitEmpty() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: MockResponses.commitsEmpty)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)
        let commit = try await api.getLastCommit(owner: "owner", repo: "repo", number: 42)

        #expect(commit == nil)
    }
}

// MARK: - API Error Handling Tests

@Suite("GitHubAPI Error Handling Tests")
struct GitHubAPIErrorHandlingTests {

    init() {
        MockURLProtocol.reset()
    }

    @Test("Handles 403 rate limit error")
    func rateLimitError() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.errorResponse(for: request, statusCode: 403, message: "API rate limit exceeded")
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)

        do {
            _ = try await api.listPRs(owner: "owner", repo: "repo")
            Issue.record("Expected error to be thrown")
        } catch let error as GitHubAPIError {
            #expect(error.description.contains("403"))
            #expect(error.description.contains("rate limit"))
        }
    }

    @Test("Handles 500 server error")
    func serverError() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.errorResponse(for: request, statusCode: 500, message: "Internal Server Error")
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)

        await #expect(throws: GitHubAPIError.self) {
            try await api.getPR(owner: "owner", repo: "repo", number: 42)
        }
    }

    @Test("Handles network timeout")
    func networkTimeout() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw MockURLProtocol.networkError(code: NSURLErrorTimedOut)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)

        await #expect(throws: Error.self) {
            try await api.listPRs(owner: "owner", repo: "repo")
        }
    }

    @Test("Handles network connection failure")
    func networkConnectionFailure() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw MockURLProtocol.networkError(code: NSURLErrorNotConnectedToInternet)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)

        await #expect(throws: Error.self) {
            try await api.getPR(owner: "owner", repo: "repo", number: 42)
        }
    }

    @Test("Handles malformed JSON response")
    func malformedJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.successResponse(for: request, jsonString: "{ invalid json }")
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "test-token", session: session)

        await #expect(throws: Error.self) {
            try await api.getPR(owner: "owner", repo: "repo", number: 42)
        }
    }

    @Test("Includes authorization header in requests")
    func authorizationHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return MockURLProtocol.successResponse(for: request, jsonString: MockResponses.emptyList)
        }

        let session = MockURLProtocol.mockSession()
        let api = GitHubAPI(token: "my-secret-token", session: session)
        _ = try await api.listPRs(owner: "owner", repo: "repo")

        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer my-secret-token")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }
}
