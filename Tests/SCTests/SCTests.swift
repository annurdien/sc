import XCTest

@testable import SC

final class SimctlManagerTests: XCTestCase {

    func testExecuteCommand() async throws {
        // Test basic command execution
        do {
            let output = try await SimctlManager.execute(["help"])
            XCTAssertFalse(output.isEmpty)
            XCTAssertTrue(output.contains("simctl"))
        } catch {
            XCTFail("Failed to execute help command: \(error)")
        }
    }

    func testInvalidCommand() async {
        do {
            _ = try await SimctlManager.execute(["invalid-command"])
            XCTFail("Should have thrown an error for invalid command")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is SimctlError)
        }
    }

    func testGetAllDevices() async throws {
        do {
            let devices = try await SimctlManager.getAllDevices()
            XCTAssertFalse(devices.isEmpty, "Should have at least some devices")

            // Verify device structure
            if let firstDevice = devices.first {
                XCTAssertFalse(firstDevice.udid.isEmpty)
                XCTAssertFalse(firstDevice.name.isEmpty)
                XCTAssertFalse(firstDevice.runtime.isEmpty)
            }
        } catch {
            XCTFail("Failed to get devices: \(error)")
        }
    }
}

final class ModelsTests: XCTestCase {

    func testDeviceModel() {
        let device = Models.Device(
            udid: "test-udid",
            name: "iPhone 15",
            state: .booted,
            runtime: "com.apple.CoreSimulator.SimRuntime.iOS-17-0"
        )

        XCTAssertEqual(device.id, "test-udid")
        XCTAssertTrue(device.isBooted)
        XCTAssertEqual(device.runtimeVersion, "iOS 17 0")
    }

    func testDeviceState() {
        XCTAssertEqual(DeviceState.booted.emoji, "🟢")
        XCTAssertEqual(DeviceState.shutdown.emoji, "⚫")
        XCTAssertEqual(DeviceState.booting.emoji, "🟡")
    }

    func testAppModel() {
        let app = App(
            bundleIdentifier: "com.test.app",
            name: "Test App",
            path: "/path/to/app",
            applicationType: .user
        )

        XCTAssertEqual(app.id, "com.test.app")
        XCTAssertEqual(app.applicationType.emoji, "📱")
    }

    func testAppType() {
        XCTAssertEqual(AppType.user.emoji, "📱")
        XCTAssertEqual(AppType.system.emoji, "⚙️")
    }
}

final class CommandTests: XCTestCase {

    func testListAppsCommand() async throws {
        // This test would require a running simulator
        // For now, we'll test command structure
        let command = ListApps()
        XCTAssertFalse(command.includeSystem)
        XCTAssertNil(command.device)
        XCTAssertFalse(command.json)
    }

    func testUserDefaultsCommand() {
        let readCommand = UserDefaults.Read()
        XCTAssertNil(readCommand.key)
        XCTAssertNil(readCommand.device)
        XCTAssertFalse(readCommand.json)
    }

    func testNotificationCommand() {
        let sendCommand = Notification.Send()
        XCTAssertNil(sendCommand.device)
        XCTAssertNil(sendCommand.identifier)
        XCTAssertNil(sendCommand.badge)
        XCTAssertNil(sendCommand.sound)
        XCTAssertNil(sendCommand.userInfo)
    }
}

// Integration tests that require a running simulator
final class IntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()

        // Check if we have a booted simulator for integration tests
        do {
            _ = try await SimctlManager.getCurrentDevice()
        } catch {
            throw XCTSkip(
                "No booted simulator found. Integration tests require a running simulator.")
        }
    }

    func testGetCurrentDevice() async throws {
        let deviceUDID = try await SimctlManager.getCurrentDevice()
        XCTAssertFalse(deviceUDID.isEmpty)
        XCTAssertTrue(deviceUDID.count > 10)  // UDIDs are longer than 10 characters
    }

    func testListAppsIntegration() async throws {
        let deviceUDID = try await SimctlManager.getCurrentDevice()
        let output = try await SimctlManager.execute(["listapps", deviceUDID])
        XCTAssertFalse(output.isEmpty)
    }
}
