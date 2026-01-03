import Foundation

/// GitHub API client
public actor GitHubAPI {
    /// Base URL for GitHub API
    static let baseURL = "https://api.github.com"

    /// GitHub token for authentication
    private let token: String

    /// URL session for requests
    private let session: URLSession

    /// JSON decoder configured for GitHub API
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// JSON encoder for request bodies
    private let encoder = JSONEncoder()

    /// Initialize with a GitHub token
    init(token: String, session: URLSession? = nil) {
        self.token = token
        // Use custom session with timeout if not provided
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15  // 15 second timeout
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API

    /// List open pull requests for a repository
    func listPRs(owner: String, repo: String) async throws -> [PullRequest] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls?state=open&per_page=100"
        return try await fetchAllPages(url: url)
    }

    /// Get a single pull request
    func getPR(owner: String, repo: String, number: Int) async throws -> PullRequest {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)"
        return try await fetch(url: url)
    }

    /// Get files changed in a pull request
    func getPRFiles(owner: String, repo: String, number: Int) async throws -> [PRFile] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/files?per_page=100"
        return try await fetchAllPages(url: url)
    }

    /// Get review comments on a pull request
    func getPRComments(owner: String, repo: String, number: Int) async throws -> [PRComment] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/comments?per_page=100"
        return try await fetchAllPages(url: url)
    }

    /// Get commits for a pull request
    func getPRCommits(owner: String, repo: String, number: Int) async throws -> [Commit] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/commits?per_page=100"
        return try await fetchAllPages(url: url)
    }

    /// Get the last commit for a pull request (optimized - fetches first page only)
    func getLastCommit(owner: String, repo: String, number: Int) async throws -> Commit? {
        // GitHub returns commits oldest-first, so we fetch first page and take the last
        // Most PRs have < 100 commits, so this works for the majority of cases
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/commits?per_page=100"
        let commits: [Commit] = try await fetch(url: url)
        return commits.last
    }

    /// Create a review comment on a pull request
    func createComment(
        owner: String,
        repo: String,
        number: Int,
        body: String,
        commitId: String,
        path: String,
        line: Int,
        side: String = "RIGHT"
    ) async throws -> PRComment {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/comments"
        let request = CreateCommentRequest(
            body: body,
            commitId: commitId,
            path: path,
            line: line,
            side: side
        )
        return try await post(url: url, body: request)
    }

    /// Submit a review on a pull request
    func submitReview(
        owner: String,
        repo: String,
        number: Int,
        event: ReviewEvent,
        body: String? = nil
    ) async throws -> ReviewResponse {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/reviews"
        let request = SubmitReviewRequest(event: event, body: body)
        return try await post(url: url, body: request)
    }

    // MARK: - URL Parsing

    /// Parse a GitHub PR URL to extract owner, repo, and number
    static func parsePRUrl(_ urlString: String) -> (owner: String, repo: String, number: Int)? {
        // Match: https://github.com/owner/repo/pull/123
        let pattern = #"github\.com/([^/]+)/([^/]+)/pull/(\d+)"#
        guard let regex = try? Regex(pattern),
              let match = urlString.wholeMatch(of: regex) ?? urlString.firstMatch(of: regex) else {
            return nil
        }

        guard match.count >= 4,
              let owner = match[1].substring.map(String.init),
              let repo = match[2].substring.map(String.init),
              let numStr = match[3].substring.map(String.init),
              let number = Int(numStr) else {
            return nil
        }

        return (owner, repo, number)
    }

    // MARK: - Private Helpers

    /// Create a request with default headers
    private func makeRequest(url: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: url) else {
            throw GitHubAPIError.invalidURL(url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("pr-review-swift", forHTTPHeaderField: "User-Agent")

        return request
    }

    /// Fetch a single resource
    private func fetch<T: Decodable>(url: String) async throws -> T {
        let request = try makeRequest(url: url)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    /// POST a resource
    private func post<T: Decodable, B: Encodable>(url: String, body: B) async throws -> T {
        var request = try makeRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    /// Fetch all pages of a paginated endpoint
    private func fetchAllPages<T: Decodable>(url: String) async throws -> [T] {
        var allItems: [T] = []
        var currentURL: String? = url

        while let urlString = currentURL {
            let request = try makeRequest(url: urlString)
            let (data, response) = try await session.data(for: request)
            try checkResponse(response, data: data)

            let items = try decoder.decode([T].self, from: data)
            allItems.append(contentsOf: items)

            // Check for next page in Link header
            if let httpResponse = response as? HTTPURLResponse,
               let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") {
                currentURL = parseLinkHeader(linkHeader)
            } else {
                currentURL = nil
            }
        }

        return allItems
    }

    /// Parse Link header for pagination
    private func parseLinkHeader(_ header: String) -> String? {
        // Link header format: <url>; rel="next", <url>; rel="last"
        for part in header.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(#"rel="next""#) {
                // Extract URL between < and >
                if let start = trimmed.firstIndex(of: "<"),
                   let end = trimmed.firstIndex(of: ">") {
                    let urlStart = trimmed.index(after: start)
                    return String(trimmed[urlStart ..< end])
                }
            }
        }
        return nil
    }

    /// Check HTTP response for errors
    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            // Try to parse error message from response
            if let errorBody = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data) {
                throw GitHubAPIError.apiError(
                    statusCode: httpResponse.statusCode,
                    message: errorBody.message
                )
            }
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

/// GitHub API errors
enum GitHubAPIError: Error, Equatable, CustomStringConvertible {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(statusCode: Int, message: String)
    case decodingError(String)

    var description: String {
        switch self {
        case let .invalidURL(url):
            "Invalid URL: \(url)"
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(statusCode):
            "HTTP error: \(statusCode)"
        case let .apiError(statusCode, message):
            "GitHub API error (\(statusCode)): \(message)"
        case let .decodingError(message):
            "Decoding error: \(message)"
        }
    }
}

/// GitHub error response body
private struct GitHubErrorResponse: Codable {
    let message: String
    let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}
