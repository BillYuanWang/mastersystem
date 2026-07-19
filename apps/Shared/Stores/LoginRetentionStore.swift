import Foundation

struct LoginRetentionStore {
    private enum Key {
        static let rememberLogin = "md.auth.rememberLogin"
        static let authenticatedAt = "md.auth.authenticatedAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var remembersLogin: Bool {
        guard defaults.object(forKey: Key.rememberLogin) != nil else { return true }
        return defaults.bool(forKey: Key.rememberLogin)
    }

    var authenticatedAt: Date? {
        guard let interval = defaults.object(forKey: Key.authenticatedAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    func setRememberLogin(_ rememberLogin: Bool) {
        defaults.set(rememberLogin, forKey: Key.rememberLogin)
    }

    func recordAuthentication(rememberLogin: Bool, at date: Date = Date()) {
        setRememberLogin(rememberLogin)
        defaults.set(date.timeIntervalSince1970, forKey: Key.authenticatedAt)
    }

    func clearAuthentication() {
        defaults.removeObject(forKey: Key.authenticatedAt)
    }
}
