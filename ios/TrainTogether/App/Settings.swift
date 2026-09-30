import Foundation
import Observation
import Security
import TrainTogetherKit

/// Where the phone syncs to. The URL lives in UserDefaults, the token in the
/// Keychain. Safe to read from any thread (the sync engine does).
final class SyncSettingsStore: Sendable {
    private static let urlKey = "sync.serverURL"

    var serverURL: String {
        UserDefaults.standard.string(forKey: Self.urlKey) ?? ""
    }

    var token: String {
        Keychain.read() ?? ""
    }

    func configuration() -> SyncConfiguration? {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = Self.normalizedURL(serverURL), !token.isEmpty else { return nil }
        return SyncConfiguration(baseURL: url, token: token)
    }

    func save(serverURL: String, token: String) throws {
        UserDefaults.standard.set(serverURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.urlKey)
        try Keychain.write(token.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func clear() throws {
        UserDefaults.standard.removeObject(forKey: Self.urlKey)
        try Keychain.write(nil)
    }

    /// Accepts "gym.example.com" or a full URL; https is assumed.
    static func normalizedURL(_ text: String) -> URL? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), url.host() != nil else { return nil }
        return url
    }
}

/// The sync token, stored as a generic password for this app only.
enum Keychain {
    private static let service = "io.github.nik5036350.traintogether.sync"
    private static let account = "token"

    struct Failure: Error, LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "KEYCHAIN ERROR \(status)" }
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String?) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        // Readable after first unlock, so background sync works while locked.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(status: status) }
    }
}

/// Per-device preferences — not synced, they describe this phone.
@MainActor @Observable
final class DeviceSettings {
    var keepScreenAwake: Bool {
        didSet { UserDefaults.standard.set(keepScreenAwake, forKey: "device.keepScreenAwake") }
    }

    var restAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(restAlertsEnabled, forKey: "device.restAlerts") }
    }

    var liveActivityEnabled: Bool {
        didSet { UserDefaults.standard.set(liveActivityEnabled, forKey: "device.liveActivity") }
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "device.keepScreenAwake": true,
            "device.restAlerts": true,
            "device.liveActivity": true,
        ])
        keepScreenAwake = defaults.bool(forKey: "device.keepScreenAwake")
        restAlertsEnabled = defaults.bool(forKey: "device.restAlerts")
        liveActivityEnabled = defaults.bool(forKey: "device.liveActivity")
    }
}

/// Free-signed builds stop launching after 7 days; the provisioning profile
/// embedded in the app says when.
enum BuildExpiry {
    static let date: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>")
        else { return nil }
        let plist = Data(text[start.lowerBound..<end.upperBound].utf8)
        let object = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any]
        return object?["ExpirationDate"] as? Date
    }()

    /// Under 48 hours left: time to re-install from Xcode.
    static func isSoon(now: Date = .now) -> Bool {
        guard let date else { return false }
        return date.timeIntervalSince(now) < 48 * 3600
    }
}
