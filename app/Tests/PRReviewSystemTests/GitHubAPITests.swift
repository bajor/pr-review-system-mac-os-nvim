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
