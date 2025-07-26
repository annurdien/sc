import ArgumentParser
import Foundation
import Rainbow

@available(macOS 10.15, *)
struct SendFile: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send files to the simulator",
        aliases: ["file"]
    )

    @Argument(help: "Local file path to send")
    var filePath: String

    @Option(name: [.short, .long], help: "Target device UDID")
    var device: String?

    @Option(name: [.short, .long], help: "Destination path on device (optional)")
    var destination: String?

    @Option(name: [.short, .long], help: "App bundle identifier to send file to")
    var bundleId: String?

    func run() async throws {
        let deviceUDID: String
        if let device = device {
            deviceUDID = device
        } else {
            deviceUDID = try await SimctlManager.getCurrentDevice()
        }

        // Validate source file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File does not exist: \(filePath)")
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent

        print("📁 Sending \(fileName.blue) to simulator...")

        if let bundleId = bundleId {
            // Send to app's Documents directory
            try await sendToApp(deviceUDID: deviceUDID, filePath: filePath, bundleId: bundleId)
        } else {
            // Send to device (will open in appropriate app)
            try await sendToDevice(deviceUDID: deviceUDID, filePath: filePath)
        }
    }

    private func sendToApp(deviceUDID: String, filePath: String, bundleId: String) async throws {
        // Get app container path
        let containerCommand = ["get_app_container", deviceUDID, bundleId, "data"]

        do {
            let containerPath = try await SimctlManager.execute(containerCommand)
            let documentsPath = "\(containerPath)/Documents"

            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            let destinationPath = "\(documentsPath)/\(fileName)"

            // Copy file to app's Documents directory
            let copyCommand = ["spawn", deviceUDID, "cp", filePath, destinationPath]
            _ = try await SimctlManager.execute(copyCommand)

            print("✅ File sent to app \(bundleId.cyan)")
            print("Location: \(destinationPath.lightBlack)")

        } catch {
            throw SimctlError.commandFailed("Failed to get app container for \(bundleId)")
        }
    }

    private func sendToDevice(deviceUDID: String, filePath: String) async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileExtension = fileURL.pathExtension.lowercased()

        // Determine the best method based on file type
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "heif":
            try await sendPhoto(deviceUDID: deviceUDID, filePath: filePath)
        case "mp4", "mov", "m4v":
            try await sendVideo(deviceUDID: deviceUDID, filePath: filePath)
        default:
            try await sendGenericFile(deviceUDID: deviceUDID, filePath: filePath)
        }
    }

    private func sendPhoto(deviceUDID: String, filePath: String) async throws {
        let command = ["addmedia", deviceUDID, filePath]
        _ = try await SimctlManager.execute(command)
        print("📸 Photo added to Photos app".bold.green)
    }

    private func sendVideo(deviceUDID: String, filePath: String) async throws {
        let command = ["addmedia", deviceUDID, filePath]
        _ = try await SimctlManager.execute(command)
        print("🎥 Video added to Photos app".bold.green)
    }

    private func sendGenericFile(deviceUDID: String, filePath: String) async throws {
        // For generic files, we'll copy to Downloads directory
        let downloadsPath = "/var/mobile/Downloads"
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let destinationPath = "\(downloadsPath)/\(fileName)"

        // Create Downloads directory if it doesn't exist
        let mkdirCommand = ["spawn", deviceUDID, "mkdir", "-p", downloadsPath]
        _ = try? await SimctlManager.execute(mkdirCommand)

        // Copy file
        let copyCommand = ["spawn", deviceUDID, "cp", filePath, destinationPath]
        _ = try await SimctlManager.execute(copyCommand)

        print("📄 File copied to device".bold.green)
        print("Location: \(destinationPath.lightBlack)")
        print("Note: Use Files app to access the file".yellow)
    }
}
