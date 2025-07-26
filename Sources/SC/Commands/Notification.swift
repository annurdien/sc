import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct Notification: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "notify",
        abstract: "Send notifications to the simulator",
        subcommands: [Send.self, Push.self],
        aliases: ["notification"]
    )

    struct Send: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "send",
            abstract: "Send a local notification"
        )

        // Default initializer for tests
        init() {
            bundleId = ""
            title = ""
            body = ""
            device = nil
            identifier = nil
            badge = nil
            sound = nil
            userInfo = nil
        }
        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "Notification title")
        var title: String

        @Argument(help: "Notification body")
        var body: String

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        @Option(name: .long, help: "Notification identifier")
        var identifier: String?

        @Option(name: .long, help: "Badge number")
        var badge: Int?

        @Option(name: .long, help: "Sound name")
        var sound: String?

        @Option(name: .long, help: "User info JSON")
        var userInfo: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            var payload: [String: Any] = [
                "Simulator Target Bundle": bundleId,
                "aps": [
                    "alert": [
                        "title": title,
                        "body": body,
                    ]
                ],
            ]

            if let badge = badge {
                var aps = payload["aps"] as! [String: Any]
                aps["badge"] = badge
                payload["aps"] = aps
            }

            if let sound = sound {
                var aps = payload["aps"] as! [String: Any]
                aps["sound"] = sound
                payload["aps"] = aps
            }

            if let userInfoString = userInfo,
                let userInfoData = userInfoString.data(using: .utf8),
                let userInfoDict = try? JSONSerialization.jsonObject(with: userInfoData)
                    as? [String: Any]
            {
                payload.merge(userInfoDict) { _, new in new }
            }

            let tempFile = NSTemporaryDirectory() + "notification_\(UUID().uuidString).json"
            let jsonData = try JSONSerialization.data(
                withJSONObject: payload, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: tempFile))

            let command = ["push", deviceUDID, tempFile]

            do {
                _ = try await SimctlManager.execute(command)
                print("📲 Successfully sent notification to \(bundleId.blue)")
                print("Title: \(title.bold)")
                print("Body: \(body)")

                // Clean up temp file
                try? FileManager.default.removeItem(atPath: tempFile)
            } catch {
                try? FileManager.default.removeItem(atPath: tempFile)
                throw error
            }
        }
    }

    struct Push: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "push",
            abstract: "Send a push notification with custom payload"
        )

        // Default initializer for tests
        init() {
            bundleId = ""
            payload = ""
            device = nil
        }
        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "JSON payload file path or JSON string")
        var payload: String

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            var payloadFile: String
            var shouldCleanup = false

            if FileManager.default.fileExists(atPath: payload) {
                payloadFile = payload
            } else {
                let tempFile = NSTemporaryDirectory() + "push_\(UUID().uuidString).json"

                guard let jsonData = payload.data(using: .utf8),
                    let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
                    let validJsonData = try? JSONSerialization.data(
                        withJSONObject: jsonObject, options: .prettyPrinted)
                else {
                    throw ValidationError("Invalid JSON payload")
                }

                var payloadDict =
                    try JSONSerialization.jsonObject(with: validJsonData) as! [String: Any]
                if payloadDict["Simulator Target Bundle"] == nil {
                    payloadDict["Simulator Target Bundle"] = bundleId
                    let updatedData = try JSONSerialization.data(
                        withJSONObject: payloadDict, options: .prettyPrinted)
                    try updatedData.write(to: URL(fileURLWithPath: tempFile))
                } else {
                    try validJsonData.write(to: URL(fileURLWithPath: tempFile))
                }

                payloadFile = tempFile
                shouldCleanup = true
            }

            let command = ["push", deviceUDID, payloadFile]

            do {
                _ = try await SimctlManager.execute(command)
                print("🚀 Successfully sent push notification to \(bundleId.blue)")

                if shouldCleanup {
                    try? FileManager.default.removeItem(atPath: payloadFile)
                }
            } catch {
                if shouldCleanup {
                    try? FileManager.default.removeItem(atPath: payloadFile)
                }
                throw error
            }
        }
    }
}
