import Foundation

// Codable helpers for simctl JSON
private struct DevicesResponse: Codable {
  let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Codable {
  let udid: String
  let name: String
  let state: DeviceState
}

struct SimctlManager {
  static func execute(_ arguments: [String]) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["simctl"] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
      throw SimctlError.commandFailed(output)
    }

    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func getCurrentDevice() async throws -> String {
    let output = try await execute(["list", "devices", "--json"])
    guard let data = output.data(using: .utf8) else {
      throw SimctlError.invalidJSON
    }
    let response = try JSONDecoder().decode(DevicesResponse.self, from: data)
    for deviceList in response.devices.values {
      for device in deviceList where device.state == .booted {
        return device.udid
      }
    }
    throw SimctlError.noBootedDevice
  }

  static func getAllDevices() async throws -> [Models.Device] {
    let output = try await execute(["list", "devices", "--json"])
    guard let data = output.data(using: .utf8) else {
      throw SimctlError.invalidJSON
    }
    let response = try JSONDecoder().decode(DevicesResponse.self, from: data)
    return response.devices.flatMap { runtime, devices in
      devices.map { sim in
        Models.Device(
          udid: sim.udid,
          name: sim.name,
          state: sim.state,
          runtime: runtime
        )
      }
    }
  }
}

enum SimctlError: LocalizedError {
  case commandFailed(String)
  case noBootedDevice
  case invalidJSON
  case deviceNotFound

  var errorDescription: String? {
    switch self {
    case .commandFailed(let output):
      return "Command failed: \(output)"
    case .noBootedDevice:
      return "No booted device found. Please boot a simulator first."
    case .invalidJSON:
      return "Invalid JSON response from simctl"
    case .deviceNotFound:
      return "Device not found"
    }
  }
}
