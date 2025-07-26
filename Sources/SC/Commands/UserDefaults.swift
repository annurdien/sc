import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct UserDefaults: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "ud",
        abstract: "Manage UserDefaults for apps",
        subcommands: [Read.self, Write.self, Delete.self, List.self],
        aliases: ["userdefaults"]
    )

    struct Read: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "read",
            abstract: "Read UserDefaults values for an app"
        )

        // Default initializer for tests
        init() {
            bundleId = ""
            key = nil
            device = nil
            json = false
        }
        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Option(name: [.short, .long], help: "Specific key to read")
        var key: String?

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        @Flag(name: .long, help: "Output in JSON format")
        var json = false

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            if let key = key {
                try await readSpecificKey(deviceUDID: deviceUDID, bundleId: bundleId, key: key)
            } else {
                try await readAllDefaults(deviceUDID: deviceUDID, bundleId: bundleId)
            }
        }

        private func readSpecificKey(deviceUDID: String, bundleId: String, key: String) async throws
        {
            let command = ["spawn", deviceUDID, "defaults", "read", bundleId, key]
            do {
                let output = try await SimctlManager.execute(command)
                if json {
                    let jsonObject = ["key": key, "value": output, "bundleId": bundleId]
                    let jsonData = try JSONSerialization.data(withJSONObject: jsonObject)
                    print(String(data: jsonData, encoding: .utf8)!)
                } else {
                    print("Key: \(key.bold.blue)")
                    print("Value: \(output.green)")
                }
            } catch {
                print("Key '\(key)' not found or error reading UserDefaults.".red)
            }
        }

        private func readAllDefaults(deviceUDID: String, bundleId: String) async throws {
            let command = ["spawn", deviceUDID, "defaults", "read", bundleId]

            do {
                let output = try await SimctlManager.execute(command)

                if json {
                    print(output)
                } else {
                    print("📋 UserDefaults for \(bundleId.bold.blue)")
                    print(String(repeating: "=", count: 60))

                    // Parse and format the plist output
                    if let data = output.data(using: .utf8),
                        let plist = try? PropertyListSerialization.propertyList(
                            from: data, format: nil) as? [String: Any]
                    {
                        printFormattedDefaults(plist)
                    } else {
                        print(output)
                    }
                }
            } catch {
                print("No UserDefaults found for bundle ID: \(bundleId)".yellow)
            }
        }

        private func printFormattedDefaults(_ defaults: [String: Any]) {
            let sortedKeys = defaults.keys.sorted()

            for key in sortedKeys {
                let value = defaults[key]!
                let valueString = formatValue(value)
                print("\(key.bold): \(valueString)")
            }

            print("\nTotal keys: \(defaults.count)".lightBlack)
        }

        private func formatValue(_ value: Any) -> String {
            switch value {
            case let string as String:
                return "\"\(string)\"".green
            case let number as NSNumber:
                return "\(number)".cyan
            case let bool as Bool:
                return (bool ? "true" : "false").magenta
            case let array as [Any]:
                return "[\(array.count) items]".yellow
            case let dict as [String: Any]:
                return "{\(dict.count) keys}".yellow
            default:
                return "\(value)".lightBlack
            }
        }
    }

    struct Write: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "write",
            abstract: "Write a value to UserDefaults"
        )

        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "Key to write")
        var key: String

        @Argument(help: "Value to write")
        var value: String

        @Option(name: [.short, .long], help: "Value type (string, int, float, bool)")
        var type: String = "string"

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            var command = ["spawn", deviceUDID, "defaults", "write", bundleId, key]

            switch type.lowercased() {
            case "int", "integer":
                command.append("-int")
            case "float", "double":
                command.append("-float")
            case "bool", "boolean":
                command.append("-bool")
            default:
                break  // string is default
            }

            command.append(value)

            _ = try await SimctlManager.execute(command)
            print("✅ Successfully wrote \(key.bold) = \(value.green) to \(bundleId.blue)")
        }
    }

    struct Delete: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a key from UserDefaults"
        )

        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "Key to delete")
        var key: String

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            let command = ["spawn", deviceUDID, "defaults", "delete", bundleId, key]

            _ = try await SimctlManager.execute(command)
            print("🗑️  Successfully deleted key \(key.bold) from \(bundleId.blue)")
        }
    }

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all UserDefaults domains"
        )

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            let command = ["spawn", deviceUDID, "defaults", "domains"]
            let output = try await SimctlManager.execute(command)

            print("📋 UserDefaults Domains".bold.blue)
            print(String(repeating: "=", count: 40))

            let domains = output.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .sorted()

            for domain in domains {
                print("• \(domain.green)")
            }

            print("\nTotal domains: \(domains.count)".lightBlack)
        }
    }
}
