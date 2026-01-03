import Foundation
import Testing
@testable import PRReviewSystem

// Note: NotificationManager singleton tests are skipped because
// UNUserNotificationCenter.current() requires app entitlements
// and crashes in test environments without them.

@Suite("NotificationManager Tests", .disabled("UNUserNotificationCenter requires app entitlements"))
struct NotificationManagerTests {

    @Test("Shared instance exists")
    func sharedInstanceExists() {
        // Skipped - accessing shared triggers UNUserNotificationCenter
    }

    @Test("Shared instance is same instance")
    func sharedInstanceIsSame() {
        // Skipped
    }

    @Test("soundEnabled defaults to true")
    func soundEnabledDefaultsToTrue() {
        // Skipped
    }

    @Test("soundEnabled can be changed")
    func soundEnabledCanBeChanged() {
        // Skipped
    }

    @Test("onOpenPR callback can be set")
    func onOpenPRCallbackCanBeSet() {
        // Skipped
    }

    @Test("onOpenPR callback receives URL")
    func onOpenPRCallbackReceivesURL() {
        // Skipped
    }
}

@Suite("NotificationManager.Category Tests")
struct NotificationManagerCategoryTests {

    @Test("Category rawValues are correct")
    func categoryRawValues() {
        #expect(NotificationManager.Category.newPR.rawValue == "NEW_PR")
        #expect(NotificationManager.Category.newCommits.rawValue == "NEW_COMMITS")
        #expect(NotificationManager.Category.newComments.rawValue == "NEW_COMMENTS")
        #expect(NotificationManager.Category.prMerged.rawValue == "PR_MERGED")
        #expect(NotificationManager.Category.prClosed.rawValue == "PR_CLOSED")
    }
}

@Suite("NotificationManager.Action Tests")
struct NotificationManagerActionTests {

    @Test("Action rawValues are correct")
    func actionRawValues() {
        #expect(NotificationManager.Action.openPR.rawValue == "OPEN_PR")
        #expect(NotificationManager.Action.dismiss.rawValue == "DISMISS")
    }
}
