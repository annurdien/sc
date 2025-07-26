import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct Install: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install an app on the simulator"
    )

    @Argument(help: "Path to .app bundle or .ipa file")
    var appPath: String

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

                guard FileManager.default.fileExists(atPath: appPath) else {
                    throw ValidationError("App path does not exist: \(appPath)")
                }

                let pathExtension = URL(fileURLWithPath: appPath).pathExtension.lowercased()
                guard pathExtension == "app" || pathExtension == "ipa" else {
                    throw ValidationError(
                        "Invalid file type. Expected .app or .ipa, got .\(pathExtension)")
                }

                print("📦 Installing app from \(appPath.blue)...")

                let command = ["install", deviceUDID, appPath]

                do {
                    _ = try await SimctlManager.execute(command)
                    print("✅ App installed successfully!".bold.green)

                    if let bundleId = try? await getBundleId(from: appPath) {
                        print("Bundle ID: \(bundleId.cyan)")
                    }
                } catch {
                    print("❌ Installation failed: \(error.localizedDescription)".red)
                    throw error
                }

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

    func getBundleId(from appPath: String) async throws -> String? {
        let infoPlistPath: String

        if appPath.hasSuffix(".app") {
            infoPlistPath = "\(appPath)/Info.plist"
        } else {
            // TODO: For .ipa files, we'd need to extract and read the Info.plist
            return nil
        }

        guard FileManager.default.fileExists(atPath: infoPlistPath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: infoPlistPath))
            let plist =
                try PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
            return plist?["CFBundleIdentifier"] as? String
        } catch {
            return nil
        }
    }
}

@available(macOS 10.15, *)
struct Uninstall: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Uninstall an app from the simulator"
    )

    @Argument(help: "App bundle identifier")
    var bundleId: String

    @Option(name: [.short, .long], help: "Target device UDID")
    var device: String?

    @Flag(name: [.short, .long], help: "Force removal without confirmation")
    var force = false

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

                if !force {
                    print(
                        "Are you sure you want to uninstall \(bundleId.bold.red)? (y/N): ",
                        terminator: "")
                    let response = readLine()?.lowercased()
                    guard response == "y" || response == "yes" else {
                        print("Cancelled.".yellow)
                        semaphore.signal()
                        return
                    }
                }

                print("🗑️  Uninstalling \(bundleId.blue)...")

                let command = ["uninstall", deviceUDID, bundleId]

                do {
                    _ = try await SimctlManager.execute(command)
                    print("✅ App uninstalled successfully!".bold.green)
                } catch {
                    print("❌ Uninstallation failed: \(error.localizedDescription)".red)
                    throw error
                }

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
