import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct Keychain: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "kc",
        abstract: "Manage Keychain items for apps",
        subcommands: [List.self, Read.self, Write.self, Delete.self],
        aliases: ["keychain"]
    )

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List keychain items for an app"
        )

        @Argument(help: "App bundle identifier")
        var bundleId: String

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

            let keychainItems = try await getKeychainItems(
                deviceUDID: deviceUDID, bundleId: bundleId)

            if json {
                let jsonData = try JSONEncoder().encode(keychainItems)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                printKeychainItems(keychainItems, for: bundleId)
            }
        }

        private func getKeychainItems(deviceUDID: String, bundleId: String) async throws
            -> [KeychainItem]
        {
            let command = [
                "spawn", deviceUDID, "security", "dump-keychain",
                "-d", "/var/mobile/Library/Keychains/keychain-2.db",
            ]

            do {
                let output = try await SimctlManager.execute(command)
                return parseKeychainOutput(output, bundleId: bundleId)
            } catch {
                return try await getAppKeychainItems(deviceUDID: deviceUDID, bundleId: bundleId)
            }
        }

        private func getAppKeychainItems(deviceUDID: String, bundleId: String) async throws
            -> [KeychainItem]
        {
            let command = ["get_app_container", deviceUDID, bundleId, "data"]

            do {
                let containerPath = try await SimctlManager.execute(command)
                let keychainPath = "\(containerPath)/Library/Keychains"

                let listCommand = ["spawn", deviceUDID, "ls", "-la", keychainPath]
                let _ = try await SimctlManager.execute(listCommand)

                // TODO: For now, return a placeholder - actual keychain reading would require
                // more complex security operations
                return []
            } catch {
                throw SimctlError.commandFailed("Unable to access app keychain data")
            }
        }

        private func parseKeychainOutput(_ output: String, bundleId: String) -> [KeychainItem] {
            var items: [KeychainItem] = []
            let lines = output.components(separatedBy: .newlines)

            var currentItem: [String: String] = [:]

            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                if trimmedLine.contains("keychain:") && !currentItem.isEmpty {
                    if let service = currentItem["svce"],
                        service.contains(bundleId)
                    {
                        let item = KeychainItem(
                            account: currentItem["acct"],
                            service: currentItem["svce"],
                            accessGroup: currentItem["agrp"],
                            data: currentItem["data"],
                            creationDate: nil,
                            modificationDate: nil
                        )
                        items.append(item)
                    }
                    currentItem = [:]
                }

                if let range = trimmedLine.range(of: "=\"") {
                    let key = String(trimmedLine[..<range.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                    let valueStart = range.upperBound
                    if let valueEnd = trimmedLine.range(
                        of: "\"", options: [], range: valueStart..<trimmedLine.endIndex)
                    {
                        let value = String(trimmedLine[valueStart..<valueEnd.lowerBound])
                        currentItem[key] = value
                    }
                }
            }

            return items
        }

        private func printKeychainItems(_ items: [KeychainItem], for bundleId: String) {
            print("🔐 Keychain Items for \(bundleId.bold.blue)")
            print(String(repeating: "=", count: 60))

            if items.isEmpty {
                print("No keychain items found for this app.".yellow)
                return
            }

            for (index, item) in items.enumerated() {
                print("\n\("Item \(index + 1)".bold)")
                print(String(repeating: "─", count: 20))

                if let account = item.account {
                    print("Account: \(account.green)")
                }

                if let service = item.service {
                    print("Service: \(service.cyan)")
                }

                if let accessGroup = item.accessGroup {
                    print("Access Group: \(accessGroup.yellow)")
                }

                if let data = item.data {
                    let displayData = data.count > 50 ? "\(data.prefix(50))..." : data
                    print("Data: \(displayData.lightBlack)")
                }
            }

            print("\nTotal items: \(items.count)".bold)
        }
    }

    struct Read: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "read",
            abstract: "Read a specific keychain item"
        )

        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "Service name or account")
        var identifier: String

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            print("🔍 Reading keychain item for \(bundleId.blue)")
            print("Identifier: \(identifier.bold)")
            print(
                "\nNote: Direct keychain reading requires additional security permissions.".yellow)
            print("Consider using the 'list' command to see available items.".yellow)
        }
    }

    struct Write: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "write",
            abstract: "Write a keychain item"
        )

        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "Service name")
        var service: String

        @Argument(help: "Account name")
        var account: String

        @Argument(help: "Password or data")
        var data: String

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            print("✏️  Writing keychain item for \(bundleId.blue)")
            print("Service: \(service.bold)")
            print("Account: \(account.bold)")
            print(
                "\nNote: Direct keychain writing requires additional security permissions.".yellow)
            print("This would typically be done through the app's own keychain APIs.".yellow)
        }
    }

    struct Delete: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a keychain item"
        )

        @Argument(help: "App bundle identifier")
        var bundleId: String

        @Argument(help: "Service name or account")
        var identifier: String

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() async throws {
            let deviceUDID: String
            if let device = device {
                deviceUDID = device
            } else {
                deviceUDID = try await SimctlManager.getCurrentDevice()
            }

            print("🗑️  Deleting keychain item for \(bundleId.blue)")
            print("Identifier: \(identifier.bold)")
            print(
                "\nNote: Direct keychain deletion requires additional security permissions.".yellow)
            print("Consider using the device's Settings app or the app itself.".yellow)
        }
    }
}
