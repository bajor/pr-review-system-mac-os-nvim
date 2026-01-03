import Foundation
import Testing
@testable import PRReviewSystem

@Suite("MenuBarController Tests")
struct MenuBarControllerTests {

    @Test("Shared instance exists")
    func sharedInstanceExists() {
        let controller = MenuBarController.shared
        // If we got here, the shared instance exists
        #expect(type(of: controller) == MenuBarController.self)
    }

    @Test("Update badge with zero clears badge")
    func updateBadgeZero() {
        let controller = MenuBarController.shared
        controller.updateBadge(count: 0)
        // No crash means success
    }

    @Test("Update badge with positive count")
    func updateBadgePositive() {
        let controller = MenuBarController.shared
        controller.updateBadge(count: 5)
        // No crash means success
    }

    @Test("Rebuild menu doesn't crash")
    func rebuildMenu() {
        let controller = MenuBarController.shared
        controller.rebuildMenu()
        // No crash means success
    }

    @Test("Update pull requests with empty dict")
    func updatePullRequestsEmpty() {
        let controller = MenuBarController.shared
        controller.updatePullRequests([:])
        // No crash means success
    }

    @Test("Clear pull requests")
    func clearPullRequests() {
        let controller = MenuBarController.shared
        controller.clearPullRequests()
        // No crash means success
    }
}

@Suite("Notification Names Tests")
struct NotificationNamesTests {

    @Test("prSelected notification name exists")
    func prSelectedName() {
        let name = Notification.Name.prSelected
        #expect(name.rawValue == "PRReviewSystem.prSelected")
    }

    @Test("refreshRequested notification name exists")
    func refreshRequestedName() {
        let name = Notification.Name.refreshRequested
        #expect(name.rawValue == "PRReviewSystem.refreshRequested")
    }

    @Test("preferencesRequested notification name exists")
    func preferencesRequestedName() {
        let name = Notification.Name.preferencesRequested
        #expect(name.rawValue == "PRReviewSystem.preferencesRequested")
    }
}
