import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct DeviceCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Control device IO and settings",
        subcommands: [List.self, Location.self, StatusBar.self],
        defaultSubcommand: List.self,
        aliases: ["dev"]
    )

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all available devices",
            aliases: ["ls", "l"]
        )

        @Flag(name: .long, help: "Output in JSON format")
        var json = false

        @Flag(name: [.short, .long], help: "Show only booted devices")
        var booted = false

        func run() throws {
            let semaphore = DispatchSemaphore(value: 0)
            var deviceList: [Models.Device] = []
            var thrownError: Error?

            Task {
                do {
                    deviceList = try await SimctlManager.getAllDevices()
                    semaphore.signal()
                } catch {
                    thrownError = error
                    semaphore.signal()
                }
            }

            semaphore.wait()

            if let error = thrownError {
                throw error
            }

            let filteredDevices = booted ? deviceList.filter { $0.isBooted } : deviceList

            if json {
                let jsonData = try JSONEncoder().encode(filteredDevices)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                printDevicesTable(devices: filteredDevices)
            }
        }

        private func printDevicesTable(devices: [Models.Device]) {
            print("📱 iOS Simulators".bold.blue)
            print(String(repeating: "=", count: 80))

            let groupedDevices = Dictionary(grouping: devices) { $0.runtimeVersion }
            let sortedRuntimes = groupedDevices.keys.sorted()

            for runtime in sortedRuntimes {
                let runtimeDevices = groupedDevices[runtime]!.sorted { $0.name < $1.name }

                print("\n\(runtime.bold.yellow)")
                print(String(repeating: "─", count: runtime.count))

                for device in runtimeDevices {
                    let status = "\(device.state.emoji) \(device.state.rawValue)"
                    let name = device.name.padding(toLength: 25, withPad: " ", startingAt: 0)
                    let udid = device.udid.prefix(8)

                    let nameColor = device.isBooted ? name.green : name.lightBlack
                    print("  \(nameColor) | \(status) | \(udid)...")
                }
            }

            let bootedCount = devices.filter { $0.isBooted }.count
            print("\nTotal devices: \(devices.count), Booted: \(bootedCount)".bold)
        }
    }

    struct Shake: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "shake",
            abstract: "Simulate device shake"
        )

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() throws {
            let semaphore = DispatchSemaphore(value: 0)
            var thrownError: Error?

            Task {
                do {
                    let deviceUDID: String
                    if let device = device {
                        deviceUDID = device
                    } else {
                        deviceUDID = try await SimctlManager.getCurrentDevice()
                    }

                    let command = ["io", deviceUDID, "shake"]
                    _ = try await SimctlManager.execute(command)

                    print("📳 Device shake simulated!".bold.yellow)
                    semaphore.signal()
                } catch {
                    thrownError = error
                    semaphore.signal()
                }
            }

            semaphore.wait()

            if let error = thrownError {
                throw error
            }
        }
    }

    struct Location: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "location",
            abstract: "Set device location"
        )

        @Argument(help: "Latitude")
        var latitude: Double

        @Argument(help: "Longitude")
        var longitude: Double

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        func run() throws {
            let semaphore = DispatchSemaphore(value: 0)
            var thrownError: Error?

            Task {
                do {
                    let deviceUDID: String
                    if let device = device {
                        deviceUDID = device
                    } else {
                        deviceUDID = try await SimctlManager.getCurrentDevice()
                    }

                    let command = ["location", deviceUDID, "set", "\(latitude),\(longitude)"]
                    _ = try await SimctlManager.execute(command)

                    print("📍 Location set to \(latitude), \(longitude)".bold.green)
                    semaphore.signal()
                } catch {
                    thrownError = error
                    semaphore.signal()
                }
            }

            semaphore.wait()

            if let error = thrownError {
                throw error
            }
        }
    }

    struct StatusBar: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "statusbar",
            abstract: "Override status bar appearance"
        )

        @Option(name: [.short, .long], help: "Target device UDID")
        var device: String?

        @Option(name: .long, help: "Battery level (0-100)")
        var batteryLevel: Int?

        @Option(name: .long, help: "Battery state (charging, charged, discharging)")
        var batteryState: String?

        @Option(name: .long, help: "Time (HH:mm)")
        var time: String?

        @Option(name: .long, help: "Cellular bars (0-4)")
        var cellularBars: Int?

        @Flag(name: .long, help: "Reset to default")
        var reset = false

        func run() throws {
            let semaphore = DispatchSemaphore(value: 0)
            var thrownError: Error?

            Task {
                do {
                    let deviceUDID: String
                    if let device = device {
                        deviceUDID = device
                    } else {
                        deviceUDID = try await SimctlManager.getCurrentDevice()
                    }

                    if reset {
                        let command = ["status_bar", deviceUDID, "clear"]
                        _ = try await SimctlManager.execute(command)
                        print("📱 Status bar reset to default".bold.green)
                        semaphore.signal()
                        return
                    }

                    var command = ["status_bar", deviceUDID, "override"]

                    if let batteryLevel = batteryLevel {
                        command.append("--batteryLevel")
                        command.append("\(batteryLevel)")
                    }

                    if let batteryState = batteryState {
                        command.append("--batteryState")
                        command.append(batteryState)
                    }

                    if let time = time {
                        command.append("--time")
                        command.append(time)
                    }

                    if let cellularBars = cellularBars {
                        command.append("--cellularBars")
                        command.append("\(cellularBars)")
                    }

                    guard command.count > 3 else {
                        print("Please specify at least one status bar override option.".yellow)
                        semaphore.signal()
                        return
                    }

                    _ = try await SimctlManager.execute(command)
                    print("📱 Status bar appearance updated".bold.green)
                    semaphore.signal()
                } catch {
                    thrownError = error
                    semaphore.signal()
                }
            }

            semaphore.wait()

            if let error = thrownError {
                throw error
            }
        }
    }
}
