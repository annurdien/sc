import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct ListApps: ParsableCommand {
    // Default initializer for tests
    init() {
        includeSystem = false
        device = nil
        json = false
    }
    static var configuration = CommandConfiguration(
        commandName: "la",
        abstract: "List installed apps on the simulator",
        aliases: ["list-apps"]
    )

    @Flag(name: [.short, .long], help: "Include system apps")
    var includeSystem = false

    @Option(name: [.short, .long], help: "Target device UDID (defaults to booted device)")
    var device: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    func run() throws {
        // Use synchronous wrapper for async code
        try runAsyncAndWait()
    }

    private func runAsyncAndWait() throws {
        var result: Result<Void, Error>!
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                try await runAsync()
                result = .success(())
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()
        try result.get()
    }

    private func runAsync() async throws {
        let deviceUDID: String
        if let device = device {
            deviceUDID = device
        } else {
            deviceUDID = try await SimctlManager.getCurrentDevice()
        }

        let apps = try await getInstalledApps(deviceUDID: deviceUDID)
        let filteredApps = includeSystem ? apps : apps.filter { $0.applicationType == .user }

        if json {
            let jsonData = try JSONEncoder().encode(filteredApps)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            printAppsTable(apps: filteredApps)
        }
    }

    private func getInstalledApps(deviceUDID: String) async throws -> [App] {
        let output = try await SimctlManager.execute(["listapps", deviceUDID])
        return try parseAppsOutput(output)
    }

    private func parseAppsOutput(_ output: String) throws -> [App] {
        var apps: [App] = []
        let lines = output.components(separatedBy: .newlines)

        var currentAppBundleId: String?
        var currentAppInfo: [String: String] = [:]

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Start of a new app entry - looks for "com.something.app" = {
            if trimmedLine.hasPrefix("\"") && trimmedLine.contains("\" =")
                && trimmedLine.hasSuffix("{")
            {
                // Save previous app if exists
                if let bundleId = currentAppBundleId, !currentAppInfo.isEmpty {
                    if let app = createApp(bundleId: bundleId, info: currentAppInfo) {
                        apps.append(app)
                    }
                }

                // Start new app - extract bundle ID from "com.apple.Bridge" = {
                if let range = trimmedLine.range(of: "\" =") {
                    currentAppBundleId = String(
                        trimmedLine[
                            trimmedLine.index(after: trimmedLine.startIndex)..<range.lowerBound])
                    currentAppInfo = [:]
                }
            }
            // Parse properties - but skip nested structures and app starts
            else if trimmedLine.contains(" = ") && !trimmedLine.contains("\" =")
                && !trimmedLine.contains(" = {") && !trimmedLine.contains("};")
                && !trimmedLine.hasPrefix("}") && currentAppBundleId != nil
            {
                let components = trimmedLine.components(separatedBy: " = ")
                if components.count >= 2 {
                    let key = components[0].trimmingCharacters(in: .whitespaces)
                    let value = components[1].trimmingCharacters(
                        in: CharacterSet(charactersIn: "\";\n\r "))
                    currentAppInfo[key] = value
                }
            }
        }

        // Don't forget the last app
        if let bundleId = currentAppBundleId, !currentAppInfo.isEmpty {
            if let app = createApp(bundleId: bundleId, info: currentAppInfo) {
                apps.append(app)
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    private func createApp(bundleId: String, info: [String: String]) -> App? {
        // Get app name - prefer CFBundleDisplayName, fallback to CFBundleName
        let name = info["CFBundleDisplayName"] ?? info["CFBundleName"] ?? bundleId

        // Get path
        guard let path = info["Path"] ?? info["Bundle"] else {
            return nil
        }

        // Determine app type
        let appType: AppType = info["ApplicationType"] == "System" ? .system : .user

        return App(
            bundleIdentifier: bundleId,
            name: name,
            path: path,
            applicationType: appType
        )
    }

    private func printAppsTable(apps: [App]) {
        guard !apps.isEmpty else {
            print("No apps found.".yellow)
            return
        }

        print("\n📱 Installed Apps".bold.blue)
        print(String(repeating: "=", count: 80))

        let maxNameLength = apps.map { $0.name.count }.max() ?? 20
        let maxBundleLength = apps.map { $0.bundleIdentifier.count }.max() ?? 30

        let nameHeader = "Name".padding(toLength: maxNameLength, withPad: " ", startingAt: 0)
        let bundleHeader = "Bundle ID".padding(
            toLength: maxBundleLength, withPad: " ", startingAt: 0)
        let typeHeader = "Type"

        print("\(nameHeader.bold) | \(bundleHeader.bold) | \(typeHeader.bold)")
        print(String(repeating: "-", count: maxNameLength + maxBundleLength + 15))

        for app in apps {
            let name = app.name.padding(toLength: maxNameLength, withPad: " ", startingAt: 0)
            let bundle = app.bundleIdentifier.padding(
                toLength: maxBundleLength, withPad: " ", startingAt: 0)
            let type = "\(app.applicationType.emoji) \(app.applicationType.rawValue)"

            let nameColor = app.applicationType == .user ? name.green : name.lightBlack
            let bundleColor = app.applicationType == .user ? bundle.cyan : bundle.lightBlack

            print("\(nameColor) | \(bundleColor) | \(type)")
        }

        print("\nTotal: \(apps.count) apps".bold)

        let userApps = apps.filter { $0.applicationType == .user }
        let systemApps = apps.filter { $0.applicationType == .system }

        if !userApps.isEmpty {
            print("📱 User apps: \(userApps.count)".green)
        }
        if !systemApps.isEmpty {
            print("⚙️  System apps: \(systemApps.count)".lightBlack)
        }
    }
}
