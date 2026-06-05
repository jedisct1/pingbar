import XCTest
@testable import PingBarLib

@MainActor
final class PreferencesViewControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.showNetworkInterfaces)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.showNetworkInterfaces)
        super.tearDown()
    }

    func testShowNetworkInterfacesCheckboxDefaultsToOnWhenUnset() {
        let viewController = PreferencesViewController()

        viewController.loadViewIfNeeded()

        XCTAssertEqual(viewController.showNetworkInterfacesCheckbox.state, .on)
    }

    func testSavePersistsShowNetworkInterfacesPreference() {
        let viewController = PreferencesViewController()
        viewController.loadViewIfNeeded()

        viewController.hostField.stringValue = "https://www.google.com"
        viewController.customDNSField.stringValue = ""
        viewController.packetLossWarningThresholdField.stringValue = "3"
        viewController.packetLossBadThresholdField.stringValue = "10"
        viewController.showNetworkInterfacesCheckbox.state = .off

        viewController.saveClicked()

        XCTAssertNotNil(UserDefaults.standard.object(forKey: UserDefaultsKey.showNetworkInterfaces))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: UserDefaultsKey.showNetworkInterfaces))
    }
}
