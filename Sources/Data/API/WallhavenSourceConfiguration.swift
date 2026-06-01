import Foundation

struct WallhavenSourceConfiguration: Equatable, Sendable {
    var categories: Set<WallhavenCategory> = Set(WallhavenCategory.allCases)
    var purities: Set<WallhavenPurity> = [.sfw]
    var order: WallhavenOrder = .descending
    var topRange: WallhavenTopRange = .oneMonth
    var apiKey: String = ""

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAPIKey: Bool {
        !trimmedAPIKey.isEmpty
    }

    var requestCategoryValue: String {
        bitField(selected: categories.isEmpty ? Set(WallhavenCategory.allCases) : categories, order: WallhavenCategory.allCases)
    }

    var requestPurityValue: String {
        requestPurityValue(hasAPIKey: hasAPIKey)
    }

    func requestPurityValue(hasAPIKey: Bool) -> String {
        var allowedPurities = purities
        if !hasAPIKey {
            allowedPurities.remove(.nsfw)
        }
        if allowedPurities.isEmpty {
            allowedPurities.insert(.sfw)
        }
        return bitField(selected: allowedPurities, order: WallhavenPurity.allCases)
    }

    mutating func toggleCategory(_ category: WallhavenCategory) {
        if categories.contains(category), categories.count > 1 {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
    }

    mutating func togglePurity(_ purity: WallhavenPurity) {
        guard purity != .nsfw || hasAPIKey else { return }
        if purities.contains(purity), purities.count > 1 {
            purities.remove(purity)
        } else {
            purities.insert(purity)
        }
    }

    mutating func setAPIKey(_ apiKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.apiKey.isEmpty {
            purities.remove(.nsfw)
            if purities.isEmpty {
                purities.insert(.sfw)
            }
        }
    }

    private func bitField<Value: Hashable>(selected: Set<Value>, order: [Value]) -> String {
        order.map { selected.contains($0) ? "1" : "0" }.joined()
    }
}

enum WallhavenCategory: String, CaseIterable, Identifiable, Sendable {
    case general
    case anime
    case people

    var id: Self { self }

    var displayName: String {
        switch self {
        case .general: return "通用"
        case .anime: return "动漫"
        case .people: return "人物"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "photo"
        case .anime: return "sparkles"
        case .people: return "person.crop.square"
        }
    }
}

enum WallhavenPurity: String, CaseIterable, Identifiable, Sendable {
    case sfw
    case sketchy
    case nsfw

    var id: Self { self }

    var displayName: String {
        switch self {
        case .sfw: return "安全"
        case .sketchy: return "擦边"
        case .nsfw: return "NSFW"
        }
    }

    var systemImage: String {
        switch self {
        case .sfw: return "checkmark.shield"
        case .sketchy: return "eye"
        case .nsfw: return "lock.open"
        }
    }
}

enum WallhavenOrder: String, CaseIterable, Identifiable, Sendable {
    case descending = "desc"
    case ascending = "asc"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .descending: return "降序"
        case .ascending: return "升序"
        }
    }
}

enum WallhavenTopRange: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "1d"
    case threeDays = "3d"
    case oneWeek = "1w"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1y"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .oneDay: return "1天"
        case .threeDays: return "3天"
        case .oneWeek: return "1周"
        case .oneMonth: return "1月"
        case .threeMonths: return "3月"
        case .sixMonths: return "6月"
        case .oneYear: return "1年"
        }
    }
}
