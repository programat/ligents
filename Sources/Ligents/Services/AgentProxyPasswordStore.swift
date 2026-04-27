import Foundation
import Security

struct AgentProxyPasswordStore {
    private let service = "\(AppConstants.bundleIdentifier).agent-proxy"
    private let account = "proxy-password"

    func loadPassword() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw AgentProxyPasswordStoreError.keychainStatus(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            throw AgentProxyPasswordStoreError.invalidPasswordData
        }

        return password
    }

    func savePassword(_ password: String) throws {
        guard let data = password.data(using: .utf8), !password.isEmpty else {
            try deletePassword()
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw AgentProxyPasswordStoreError.keychainStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AgentProxyPasswordStoreError.keychainStatus(addStatus)
        }
    }

    func deletePassword() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AgentProxyPasswordStoreError.keychainStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum AgentProxyPasswordStoreError: LocalizedError {
    case keychainStatus(OSStatus)
    case invalidPasswordData

    var errorDescription: String? {
        switch self {
        case .keychainStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error \(status)."
        case .invalidPasswordData:
            return "Stored proxy password is not valid UTF-8."
        }
    }
}
