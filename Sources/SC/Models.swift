import Foundation

enum Models {
  struct Device: Codable, Identifiable {
    let udid: String
    let name: String
    let state: DeviceState
    let runtime: String
    
    var id: String { udid }
    
    var isBooted: Bool {
      state == .booted
    }
    
    var runtimeVersion: String {
      runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        .replacingOccurrences(of: "-", with: " ")
    }
  }
}

enum DeviceState: String, Codable, CaseIterable {
  case shutdown = "Shutdown"
  case booted = "Booted"
  case booting = "Booting"
  case shuttingDown = "Shutting Down"
  case creating = "Creating"
  
  var emoji: String {
    switch self {
    case .shutdown: return "⚫"
    case .booted: return "🟢"
    case .booting: return "🟡"
    case .shuttingDown: return "🟠"
    case .creating: return "🔵"
    }
  }
}

struct App: Codable, Identifiable {
  let bundleIdentifier: String
  let name: String
  let path: String
  let applicationType: AppType
  
  var id: String { bundleIdentifier }
}

enum AppType: String, Codable, CaseIterable {
  case user = "User"
  case system = "System"
  
  var emoji: String {
    switch self {
    case .user: return "📱"
    case .system: return "⚙️"
    }
  }
}

struct UserDefaultsEntry {
  let key: String
  let value: Any
  let type: String
  
  init(key: String, value: Any) {
    self.key = key
    self.value = value
    self.type = String(describing: Swift.type(of: value))
  }
}

struct KeychainItem: Codable {
  let account: String?
  let service: String?
  let accessGroup: String?
  let data: String?
  let creationDate: Date?
  let modificationDate: Date?
}
