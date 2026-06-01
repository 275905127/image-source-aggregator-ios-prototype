import Foundation

struct WallpaperSourceEngineStore {
    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let enginesKey = "wallpaper.sourceEngines"
    private let activeEngineIDKey = "wallpaper.sourceEngines.active"
    private let didSeedDefaultEngineKey = "wallpaper.sourceEngines.didSeedDefault"
    private let keychainAccountPrefix = "source-engine-api-key"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func loadEngines() -> [WallpaperSourceEngine] {
        guard let data = defaults.data(forKey: enginesKey),
               let engines = try? decoder.decode([WallpaperSourceEngine].self, from: data),
               !engines.isEmpty else {
            defaults.set(true, forKey: didSeedDefaultEngineKey)
            return [.wallhavenTemplate]
        }
        var didMigrateLegacySecrets = false
        let migratedEngines = engines.map { source in
            var source = source
            let legacyAPIKey = source.trimmedAPIKey
            if let storedKey = keychain.string(for: keychainAccount(for: source.id)) {
                source.apiKey = storedKey
                didMigrateLegacySecrets = didMigrateLegacySecrets || !legacyAPIKey.isEmpty
            } else if !source.apiKey.isEmpty {
                persistAPIKey(for: source)
                didMigrateLegacySecrets = true
            }
            return source
        }
        if didMigrateLegacySecrets, let data = try? encoder.encode(migratedEngines) {
            defaults.set(data, forKey: enginesKey)
        }
        return migratedEngines
    }

    func loadActiveEngineID(engines: [WallpaperSourceEngine]) -> UUID {
        if let rawValue = defaults.string(forKey: activeEngineIDKey),
           let id = UUID(uuidString: rawValue),
           engines.contains(where: { $0.id == id }) {
            return id
        }
        return engines.first?.id ?? WallpaperSourceEngine.wallhavenTemplateID
    }

    func save(engines: [WallpaperSourceEngine], activeEngineID: UUID) {
        let safeEngines = engines.isEmpty ? [WallpaperSourceEngine.wallhavenTemplate] : engines
        for source in safeEngines {
            persistAPIKey(for: source)
        }
        if let data = try? encoder.encode(safeEngines) {
            defaults.set(data, forKey: enginesKey)
        }
        defaults.set(activeEngineID.uuidString, forKey: activeEngineIDKey)
        defaults.set(true, forKey: didSeedDefaultEngineKey)
    }

    func deleteSecrets(for sourceEngine: WallpaperSourceEngine) {
        try? keychain.removeValue(for: keychainAccount(for: sourceEngine.id))
    }

    private func persistAPIKey(for sourceEngine: WallpaperSourceEngine) {
        let account = keychainAccount(for: sourceEngine.id)
        if sourceEngine.trimmedAPIKey.isEmpty {
            try? keychain.removeValue(for: account)
        } else {
            try? keychain.setString(sourceEngine.trimmedAPIKey, for: account)
        }
    }

    private func keychainAccount(for id: UUID) -> String {
        "\(keychainAccountPrefix).\(id.uuidString)"
    }
}
