import ArgumentParser
import Foundation

struct SC: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sc",
        abstract: "A powerful CLI tool for iOS Simulator management",
        discussion: """
            SC is a wrapper around xcrun simctl that makes iOS Simulator management easier and more powerful.

            Features:
            • List apps with beautiful formatting
            • Manage UserDefaults and Keychain
            • Send notifications and files
            • Control device IO
            • Install/uninstall apps
            """,
        version: "1.0.0",
        subcommands: [
            ListApps.self,
            UserDefaults.self,
            Keychain.self,
            Notification.self,
            DeviceCommand.self,
            Install.self,
            Uninstall.self,
            SendFile.self,
        ]
    )
}

// Entry point
SC.main()
