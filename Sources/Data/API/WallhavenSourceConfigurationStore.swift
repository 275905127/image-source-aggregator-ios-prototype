import Foundation

struct WallhavenSourceConfigurationStore {
    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let categoriesKey = "wallhaven.source.categories"
    private let puritiesKey = "wallhaven.source.purities"
    private let orderKey = "wallhaven.source.order"
    private let topRangeKey = "wallhaven.source.topRange"
    private let apiKeyKey = "wallhaven.source.apiKey"
    private let keychainAccount = "wallhaven.source.apiKey"

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func load() -> WallhavenSourceConfiguration {
        var configuration = WallhavenSourceConfiguration()
        if let categories = loadSet(forKey: categoriesKey, values: WallhavenCategory.allCases) {
            configuration.categories = categories
        }
        if let purities = loadSet(forKey: puritiesKey, values: WallhavenPurity.allCases) {
            configuration.purities = purities
        }
        if let orderValue = defaults.string(forKey: orderKey),
           let order = WallhavenOrder(rawValue: orderValue) {
            configuration.order = order
        }
        if let topRangeValue = defaults.string(forKey: topRangeKey),
           let topRange = WallhavenTopRange(rawValue: topRangeValue) {
            configuration.topRange = topRange
        }
        let keychainAPIKey = keychain.string(for: keychainAccount)
        let legacyAPIKey = defaults.string(forKey: apiKeyKey) ?? ""
        let storedAPIKey = keychainAPIKey ?? legacyAPIKey
        configuration.setAPIKey(storedAPIKey)
        if keychainAPIKey == nil, !legacyAPIKey.isEmpty {
            try? keychain.setString(legacyAPIKey, for: keychainAccount)
        }
        if !legacyAPIKey.isEmpty {
            defaults.removeObject(forKey: apiKeyKey)
        }
        return configuration
    }

    func save(_ configuration: WallhavenSourceConfiguration) {
        defaults.set(configuration.categories.map(\.rawValue), forKey: categoriesKey)
        defaults.set(configuration.purities.map(\.rawValue), forKey: puritiesKey)
        defaults.set(configuration.order.rawValue, forKey: orderKey)
        defaults.set(configuration.topRange.rawValue, forKey: topRangeKey)
        defaults.removeObject(forKey: apiKeyKey)
        if configuration.trimmedAPIKey.isEmpty {
            try? keychain.removeValue(for: keychainAccount)
        } else {
            try? keychain.setString(configuration.trimmedAPIKey, for: keychainAccount)
        }
    }

    private func loadSet<Value: RawRepresentable & Hashable>(forKey key: String, values: [Value]) -> Set<Value>? where Value.RawValue == String {
        guard let storedValues = defaults.stringArray(forKey: key) else { return nil }
        let allowedValues = Set(values)
        let decodedValues = Set(storedValues.compactMap(Value.init(rawValue:))).intersection(allowedValues)
        return decodedValues.isEmpty ? nil : decodedValues
    }
}
