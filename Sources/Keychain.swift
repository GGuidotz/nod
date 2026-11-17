// I segreti di ntfy (token di accesso, token dei pulsanti, topic), nel Portachiavi dell'utente (mai in UserDefaults).

import Foundation
import Security

enum Keychain {
    private static let service = "local.nod.companion"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Una stringa vuota cancella la voce. Restituisce false solo se la scrittura non è riuscita.
    @discardableResult
    static func write(_ value: String, for account: String) -> Bool {
        let match: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(match as CFDictionary)
        guard !value.isEmpty else { return true }
        var add = match
        add[kSecValueData as String] = Data(value.utf8)
        // Solo dopo il primo sblocco e mai in un backup o su un altro dispositivo.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
