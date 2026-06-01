import Foundation

struct Endpoint {
    let path: String
    let queryItems: [URLQueryItem]
    let baseURL: String
    let method: String
    let headers: [String: String]

    init(
        baseURL: String = "https://wallhaven.cc/api/v1",
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
        self.method = method
        self.headers = headers
    }

    func buildURLRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.isEmpty ? "GET" : method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        for (name, value) in headers where !name.isEmpty && !value.isEmpty {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}

extension Endpoint {
    static func search(
        query: String = "",
        page: Int = 1,
        sorting: WallhavenSorting = .toplist,
        configuration: WallhavenSourceConfiguration = WallhavenSourceConfiguration(),
        sourceEngine: WallpaperSourceEngine = .wallhavenTemplate
    ) -> Endpoint {
        let hasAPIKey = sourceEngine.hasAPIKey || configuration.hasAPIKey
        let apiKey = sourceEngine.hasAPIKey ? sourceEngine.trimmedAPIKey : configuration.trimmedAPIKey
        let apiKeyName = sourceEngine.request.apiKeyQueryName.isEmpty ? "apikey" : sourceEngine.request.apiKeyQueryName
        let controlledQueryNames = Set([
            "q", "page", "sorting", "categories", "purity", "order", "toprange", apiKeyName.lowercased()
        ])
        var items = sourceEngine.request.staticQueryItems
            .filter { !controlledQueryNames.contains($0.name.lowercased()) }
            .map { URLQueryItem(name: $0.name, value: $0.value) }
        items.append(contentsOf: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sorting", value: sorting.rawValue),
            URLQueryItem(name: "categories", value: configuration.requestCategoryValue),
            URLQueryItem(name: "purity", value: configuration.requestPurityValue(hasAPIKey: hasAPIKey)),
            URLQueryItem(name: "order", value: configuration.order.rawValue),
        ])
        if sorting == .toplist {
            items.append(URLQueryItem(name: "topRange", value: configuration.topRange.rawValue))
        }
        if hasAPIKey, sourceEngine.request.apiKeyPlacement == .query {
            items.append(URLQueryItem(name: apiKeyName, value: apiKey))
        }
        return Endpoint(
            baseURL: sourceEngine.request.normalizedBaseURL,
            path: sourceEngine.request.pathTemplate,
            queryItems: items,
            method: sourceEngine.request.method,
            headers: sourceEngine.request.headerFields(apiKey: apiKey)
        )
    }

    static func wallpaperDetail(id: String, apiKey: String? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let key = apiKey, !key.isEmpty {
            items.append(URLQueryItem(name: "apikey", value: key))
        }
        return Endpoint(path: "/w/\(id)", queryItems: items)
    }
}

enum WallhavenSorting: String, CaseIterable {
    case toplist = "toplist"
    case hot = "views"
    case random = "random"
    case dateAdded = "date_added"
    case relevance = "relevance"

    var displayName: String {
        switch self {
        case .toplist: return "热门推荐"
        case .hot: return "最多浏览"
        case .random: return "随机发现"
        case .dateAdded: return "最新上传"
        case .relevance: return "最相关"
        }
    }
}
