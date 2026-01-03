import Testing
@testable import PRReviewSystem

@Suite("PRReviewSystem Tests")
struct PRReviewSystemTests {

    @Test("Version is not empty")
    func versionIsNotEmpty() {
        let version = getVersion()
        #expect(!version.isEmpty, "Version should not be empty")
    }

    @Test("Version matches semver format")
    func versionFormat() {
        let version = getVersion()
        // Version should match semver format: X.Y.Z
        let pattern = #"^\d+\.\d+\.\d+$"#
        let regex = try? Regex(pattern)
        let match = version.wholeMatch(of: regex!)
        #expect(match != nil, "Version '\(version)' should match semver format X.Y.Z")
    }
}
