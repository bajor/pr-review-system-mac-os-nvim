import Foundation
import Testing
@testable import PRReviewSystem

@Suite("CleanupService Tests")
struct CleanupServiceTests {

    /// Test directory for cleanup tests
    private let testRoot = "/tmp/claude/pr-review-cleanup-tests"

    @Test("Can be initialized with clone root")
    func initWithCloneRoot() {
        let service = CleanupService(cloneRoot: "/tmp/test", maxAgeDays: 30)
        #expect(service != nil)
    }

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
        let service = CleanupService(config: config)
        #expect(service != nil)
    }

    @Test("shouldRunCleanup returns true initially")
    func shouldRunCleanupInitially() throws {
        // Use a completely unique parent directory to avoid shared state
        let uniqueParent = testRoot + "/fresh1-\(UUID().uuidString)"
        let uniqueRoot = uniqueParent + "/repos"
        // Remove any existing state file
        try? FileManager.default.removeItem(atPath: uniqueParent + "/state.json")
        let service = CleanupService(cloneRoot: uniqueRoot, maxAgeDays: 30)
        #expect(service.shouldRunCleanup() == true)
    }

    @Test("lastCleanupDate returns nil initially")
    func lastCleanupDateInitially() throws {
        // Use a completely unique parent directory to avoid shared state
        let uniqueParent = testRoot + "/fresh2-\(UUID().uuidString)"
        let uniqueRoot = uniqueParent + "/repos"
        // Remove any existing state file
        try? FileManager.default.removeItem(atPath: uniqueParent + "/state.json")
        let service = CleanupService(cloneRoot: uniqueRoot, maxAgeDays: 30)
        #expect(service.lastCleanupDate() == nil)
    }

    @Test("previewCleanup returns empty for non-existent directory")
    func previewCleanupNonExistent() {
        let service = CleanupService(cloneRoot: testRoot + "/nonexistent", maxAgeDays: 30)
        let result = service.previewCleanup()
        #expect(result.isEmpty)
    }

    @Test("runCleanup returns zero count for non-existent directory")
    func runCleanupNonExistent() {
        let service = CleanupService(cloneRoot: testRoot + "/nonexistent2", maxAgeDays: 30)
        let result = service.runCleanup()
        #expect(result.deletedCount == 0)
        #expect(result.freedBytes == 0)
        #expect(result.errors.isEmpty)
    }

    @Test("runCleanup updates lastCleanupDate")
    func runCleanupUpdatesDate() {
        let service = CleanupService(cloneRoot: testRoot + "/test3", maxAgeDays: 30)
        _ = service.runCleanup()
        #expect(service.lastCleanupDate() != nil)
    }

    @Test("shouldRunCleanup returns false after recent cleanup")
    func shouldRunCleanupAfterRecentCleanup() {
        let service = CleanupService(cloneRoot: testRoot + "/test4", maxAgeDays: 30)
        _ = service.runCleanup()
        #expect(service.shouldRunCleanup() == false)
    }
}

@Suite("CleanupResult Tests")
struct CleanupResultTests {

    @Test("CleanupResult equality")
    func resultEquality() {
        let result1 = CleanupService.CleanupResult(deletedCount: 5, freedBytes: 1000, errors: [])
        let result2 = CleanupService.CleanupResult(deletedCount: 5, freedBytes: 1000, errors: [])
        #expect(result1 == result2)
    }

    @Test("CleanupResult inequality for different count")
    func resultInequalityCount() {
        let result1 = CleanupService.CleanupResult(deletedCount: 5, freedBytes: 1000, errors: [])
        let result2 = CleanupService.CleanupResult(deletedCount: 3, freedBytes: 1000, errors: [])
        #expect(result1 != result2)
    }

    @Test("CleanupResult freedMB calculation")
    func freedMBCalculation() {
        let result = CleanupService.CleanupResult(deletedCount: 1, freedBytes: 1024 * 1024, errors: [])
        #expect(result.freedMB == 1.0)
    }

    @Test("CleanupResult freedMB for partial MB")
    func freedMBPartial() {
        let result = CleanupService.CleanupResult(deletedCount: 1, freedBytes: 512 * 1024, errors: [])
        #expect(result.freedMB == 0.5)
    }

    @Test("CleanupResult freedMB for zero bytes")
    func freedMBZero() {
        let result = CleanupService.CleanupResult(deletedCount: 0, freedBytes: 0, errors: [])
        #expect(result.freedMB == 0.0)
    }
}
