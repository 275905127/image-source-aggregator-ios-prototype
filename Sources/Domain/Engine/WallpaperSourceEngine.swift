import Foundation

struct WallpaperSourceEngine: Identifiable, Codable, Equatable, Sendable {
    static let wallhavenTemplateID = UUID(uuidString: "8E7788CB-0AF9-4F97-8C9B-0C898AC7E601")!

    var id: UUID
    var name: String
    var kind: WallpaperSourceEngineKind
    var request: SourceEngineRequest
    var mapping: SourceEngineMapping
    var directImages: [String]
    var apiKey: String

    init(
        id: UUID = UUID(),
        name: String,
        kind: WallpaperSourceEngineKind,
        request: SourceEngineRequest = SourceEngineRequest(),
        mapping: SourceEngineMapping = SourceEngineMapping(),
        directImages: [String] = [],
        apiKey: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.request = request
        self.mapping = mapping
        self.directImages = directImages
        self.apiKey = apiKey
    }

    static var wallhavenTemplate: WallpaperSourceEngine {
        WallpaperSourceEngine(
            id: wallhavenTemplateID,
            name: "Wallhaven",
            kind: .wallhaven,
            request: SourceEngineRequest(
                baseURL: "https://wallhaven.cc/api/v1",
                pathTemplate: "/search",
                pageQueryName: "page",
                searchQueryName: "q"
            ),
            mapping: SourceEngineMapping(
                itemsPath: "data",
                idPath: "id",
                thumbnailURLPath: "thumbs.large",
                fullImageURLPath: "path",
                titlePath: "tags.0.name",
                authorPath: "uploader.username",
                widthPath: "dimension_x",
                heightPath: "dimension_y",
                viewsPath: "views",
                favoritesPath: "favorites",
                categoryPath: "category",
                purityPath: "purity",
                fileSizePath: "file_size",
                fileTypePath: "file_type",
                createdAtPath: "created_at",
                sourceURLPath: "url",
                colorsPath: "colors",
                lastPagePath: "meta.last_page"
            )
        )
    }

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAPIKey: Bool {
        !trimmedAPIKey.isEmpty
    }

    var supportsWallhavenFilters: Bool {
        kind == .wallhaven
            || id == Self.wallhavenTemplateID
            || request.normalizedBaseURL.localizedCaseInsensitiveContains("wallhaven.cc")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case request
        case mapping
        case directImages
        case apiKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(WallpaperSourceEngineKind.self, forKey: .kind)
        request = try container.decodeIfPresent(SourceEngineRequest.self, forKey: .request) ?? SourceEngineRequest()
        mapping = try container.decodeIfPresent(SourceEngineMapping.self, forKey: .mapping) ?? SourceEngineMapping()
        directImages = try container.decodeIfPresent([String].self, forKey: .directImages) ?? []
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(request, forKey: .request)
        try container.encode(mapping, forKey: .mapping)
        try container.encode(directImages, forKey: .directImages)
    }
}

enum WallpaperSourceEngineKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case wallhaven
    case jsonAPI
    case directLinks

    var id: Self { self }

    var displayName: String {
        switch self {
        case .wallhaven: return "Wallhaven 模板"
        case .jsonAPI: return "JSON API 引擎"
        case .directLinks: return "图片直链引擎"
        }
    }

    var systemImage: String {
        switch self {
        case .wallhaven: return "network"
        case .jsonAPI: return "curlybraces"
        case .directLinks: return "link"
        }
    }
}

struct SourceEngineRequest: Codable, Equatable, Sendable {
    var baseURL: String = ""
    var pathTemplate: String = ""
    var method: String = "GET"
    var pageQueryName: String = "page"
    var searchQueryName: String = "q"
    var apiKeyQueryName: String = "apikey"
    var apiKeyPlacement: SourceEngineAPIKeyPlacement = .query
    var staticHeaders: [SourceEngineHeader] = []
    var staticQueryItems: [SourceEngineQueryItem] = []

    init(
        baseURL: String = "",
        pathTemplate: String = "",
        method: String = "GET",
        pageQueryName: String = "page",
        searchQueryName: String = "q",
        apiKeyQueryName: String = "apikey",
        apiKeyPlacement: SourceEngineAPIKeyPlacement = .query,
        staticHeaders: [SourceEngineHeader] = [],
        staticQueryItems: [SourceEngineQueryItem] = []
    ) {
        self.baseURL = baseURL
        self.pathTemplate = pathTemplate
        self.method = method
        self.pageQueryName = pageQueryName
        self.searchQueryName = searchQueryName
        self.apiKeyQueryName = apiKeyQueryName
        self.apiKeyPlacement = apiKeyPlacement
        self.staticHeaders = staticHeaders
        self.staticQueryItems = staticQueryItems
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case pathTemplate
        case method
        case pageQueryName
        case searchQueryName
        case apiKeyQueryName
        case apiKeyPlacement
        case staticHeaders
        case staticQueryItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        pathTemplate = try container.decodeIfPresent(String.self, forKey: .pathTemplate) ?? ""
        method = try container.decodeIfPresent(String.self, forKey: .method) ?? "GET"
        pageQueryName = try container.decodeIfPresent(String.self, forKey: .pageQueryName) ?? "page"
        searchQueryName = try container.decodeIfPresent(String.self, forKey: .searchQueryName) ?? "q"
        apiKeyQueryName = try container.decodeIfPresent(String.self, forKey: .apiKeyQueryName) ?? "apikey"
        apiKeyPlacement = try container.decodeIfPresent(SourceEngineAPIKeyPlacement.self, forKey: .apiKeyPlacement) ?? .query
        staticHeaders = try container.decodeIfPresent([SourceEngineHeader].self, forKey: .staticHeaders) ?? []
        staticQueryItems = try container.decodeIfPresent([SourceEngineQueryItem].self, forKey: .staticQueryItems) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(pathTemplate, forKey: .pathTemplate)
        try container.encode(method, forKey: .method)
        try container.encode(pageQueryName, forKey: .pageQueryName)
        try container.encode(searchQueryName, forKey: .searchQueryName)
        try container.encode(apiKeyQueryName, forKey: .apiKeyQueryName)
        try container.encode(apiKeyPlacement, forKey: .apiKeyPlacement)
        try container.encode(staticHeaders, forKey: .staticHeaders)
        try container.encode(staticQueryItems, forKey: .staticQueryItems)
    }

    var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return withScheme.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func from(urlString: String) -> SourceEngineRequest {
        guard let components = URLComponents(string: urlString.withHTTPSIfNeeded),
              let host = components.host else {
            return SourceEngineRequest(baseURL: urlString, pathTemplate: "")
        }

        let scheme = components.scheme ?? "https"
        return SourceEngineRequest(
            baseURL: "\(scheme)://\(host)",
            pathTemplate: components.path,
            method: "GET",
            pageQueryName: "page",
            searchQueryName: "q",
            apiKeyQueryName: "apikey",
            staticQueryItems: components.queryItems?.map {
                SourceEngineQueryItem(name: $0.name, value: $0.value ?? "")
            } ?? []
        )
    }

    static func wallhavenCompatible(from urlString: String) -> SourceEngineRequest {
        var request = SourceEngineRequest.from(urlString: urlString)
        request.baseURL = "https://wallhaven.cc/api/v1"
        request.pathTemplate = request.pathTemplate.isEmpty ? "/search" : request.pathTemplate
        return request
    }

    func headerFields(apiKey: String = "") -> [String: String] {
        var headers: [String: String] = [:]
        for header in staticHeaders where !header.name.isEmpty && !header.value.isEmpty {
            headers[header.name] = header.value
        }
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else { return headers }
        switch apiKeyPlacement {
        case .query:
            return headers
        case .header:
            headers[apiKeyQueryName] = trimmedAPIKey
        case .bearer:
            headers[apiKeyQueryName.isEmpty ? "Authorization" : apiKeyQueryName] = "Bearer \(trimmedAPIKey)"
        }
        return headers
    }
}

struct SourceEngineQueryItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var value: String
}

struct SourceEngineHeader: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var value: String
}

enum SourceEngineAPIKeyPlacement: String, Codable, Sendable {
    case query
    case header
    case bearer
}

struct SourceEngineMapping: Codable, Equatable, Sendable {
    var itemsPath: String = "data"
    var idPath: String = "id"
    var thumbnailURLPath: String = "thumbnail"
    var fullImageURLPath: String = "url"
    var thumbnailURLPrefix: String?
    var fullImageURLPrefix: String?
    var titlePath: String = "title"
    var authorPath: String = ""
    var widthPath: String = ""
    var heightPath: String = ""
    var viewsPath: String = ""
    var favoritesPath: String = ""
    var categoryPath: String = ""
    var purityPath: String = ""
    var fileSizePath: String = ""
    var fileTypePath: String = ""
    var createdAtPath: String = ""
    var sourceURLPath: String = ""
    var colorsPath: String = ""
    var lastPagePath: String = ""
    var hasMorePath: String = ""
    var nextPagePath: String = ""
    var defaultHasMore: Bool? = nil

    init(
        itemsPath: String = "data",
        idPath: String = "id",
        thumbnailURLPath: String = "thumbnail",
        fullImageURLPath: String = "url",
        thumbnailURLPrefix: String? = nil,
        fullImageURLPrefix: String? = nil,
        titlePath: String = "title",
        authorPath: String = "",
        widthPath: String = "",
        heightPath: String = "",
        viewsPath: String = "",
        favoritesPath: String = "",
        categoryPath: String = "",
        purityPath: String = "",
        fileSizePath: String = "",
        fileTypePath: String = "",
        createdAtPath: String = "",
        sourceURLPath: String = "",
        colorsPath: String = "",
        lastPagePath: String = "",
        hasMorePath: String = "",
        nextPagePath: String = "",
        defaultHasMore: Bool? = nil
    ) {
        self.itemsPath = itemsPath
        self.idPath = idPath
        self.thumbnailURLPath = thumbnailURLPath
        self.fullImageURLPath = fullImageURLPath
        self.thumbnailURLPrefix = thumbnailURLPrefix
        self.fullImageURLPrefix = fullImageURLPrefix
        self.titlePath = titlePath
        self.authorPath = authorPath
        self.widthPath = widthPath
        self.heightPath = heightPath
        self.viewsPath = viewsPath
        self.favoritesPath = favoritesPath
        self.categoryPath = categoryPath
        self.purityPath = purityPath
        self.fileSizePath = fileSizePath
        self.fileTypePath = fileTypePath
        self.createdAtPath = createdAtPath
        self.sourceURLPath = sourceURLPath
        self.colorsPath = colorsPath
        self.lastPagePath = lastPagePath
        self.hasMorePath = hasMorePath
        self.nextPagePath = nextPagePath
        self.defaultHasMore = defaultHasMore
    }

    private enum CodingKeys: String, CodingKey {
        case itemsPath
        case idPath
        case thumbnailURLPath
        case fullImageURLPath
        case thumbnailURLPrefix
        case fullImageURLPrefix
        case titlePath
        case authorPath
        case widthPath
        case heightPath
        case viewsPath
        case favoritesPath
        case categoryPath
        case purityPath
        case fileSizePath
        case fileTypePath
        case createdAtPath
        case sourceURLPath
        case colorsPath
        case lastPagePath
        case hasMorePath
        case nextPagePath
        case defaultHasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemsPath = try container.decodeIfPresent(String.self, forKey: .itemsPath) ?? "data"
        idPath = try container.decodeIfPresent(String.self, forKey: .idPath) ?? "id"
        thumbnailURLPath = try container.decodeIfPresent(String.self, forKey: .thumbnailURLPath) ?? "thumbnail"
        fullImageURLPath = try container.decodeIfPresent(String.self, forKey: .fullImageURLPath) ?? "url"
        thumbnailURLPrefix = try container.decodeIfPresent(String.self, forKey: .thumbnailURLPrefix)
        fullImageURLPrefix = try container.decodeIfPresent(String.self, forKey: .fullImageURLPrefix)
        titlePath = try container.decodeIfPresent(String.self, forKey: .titlePath) ?? "title"
        authorPath = try container.decodeIfPresent(String.self, forKey: .authorPath) ?? ""
        widthPath = try container.decodeIfPresent(String.self, forKey: .widthPath) ?? ""
        heightPath = try container.decodeIfPresent(String.self, forKey: .heightPath) ?? ""
        viewsPath = try container.decodeIfPresent(String.self, forKey: .viewsPath) ?? ""
        favoritesPath = try container.decodeIfPresent(String.self, forKey: .favoritesPath) ?? ""
        categoryPath = try container.decodeIfPresent(String.self, forKey: .categoryPath) ?? ""
        purityPath = try container.decodeIfPresent(String.self, forKey: .purityPath) ?? ""
        fileSizePath = try container.decodeIfPresent(String.self, forKey: .fileSizePath) ?? ""
        fileTypePath = try container.decodeIfPresent(String.self, forKey: .fileTypePath) ?? ""
        createdAtPath = try container.decodeIfPresent(String.self, forKey: .createdAtPath) ?? ""
        sourceURLPath = try container.decodeIfPresent(String.self, forKey: .sourceURLPath) ?? ""
        colorsPath = try container.decodeIfPresent(String.self, forKey: .colorsPath) ?? ""
        lastPagePath = try container.decodeIfPresent(String.self, forKey: .lastPagePath) ?? ""
        hasMorePath = try container.decodeIfPresent(String.self, forKey: .hasMorePath) ?? ""
        nextPagePath = try container.decodeIfPresent(String.self, forKey: .nextPagePath) ?? ""
        defaultHasMore = try container.decodeIfPresent(Bool.self, forKey: .defaultHasMore)
    }
}

private extension String {
    var withHTTPSIfNeeded: String {
        contains("://") ? self : "https://\(self)"
    }
}

extension WallpaperSourceEngine {
    func endpoint(query: String, page: Int) throws -> Endpoint {
        let baseURL = request.normalizedBaseURL
        guard !baseURL.isEmpty else { throw NetworkError.invalidURL }
        var items = request.staticQueryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
        if !request.pageQueryName.isEmpty {
            items.append(URLQueryItem(name: request.pageQueryName, value: String(page)))
        }
        if !request.searchQueryName.isEmpty, !query.isEmpty {
            items.append(URLQueryItem(name: request.searchQueryName, value: query))
        }
        if hasAPIKey, request.apiKeyPlacement == .query, !request.apiKeyQueryName.isEmpty {
            items.append(URLQueryItem(name: request.apiKeyQueryName, value: trimmedAPIKey))
        }
        return Endpoint(
            baseURL: baseURL,
            path: request.pathTemplate,
            queryItems: items,
            method: request.method,
            headers: request.headerFields(apiKey: trimmedAPIKey)
        )
    }

    func decodeWallpapers(from root: Any, page: Int) throws -> (wallpapers: [Wallpaper], hasMore: Bool) {
        guard let items = itemArray(in: root) else {
            throw NetworkError.invalidResponse
        }

        let wallpapers = items.compactMap { item -> Wallpaper? in
            guard let fullImageURL = firstURLValue(
                in: item,
                paths: fullImagePathCandidates,
                prefix: mapping.fullImageURLPrefix
            ).flatMap({ URL(string: $0) }) else {
                return nil
            }
            let thumbnailURL = firstURLValue(
                in: item,
                paths: thumbnailPathCandidates,
                prefix: mapping.thumbnailURLPrefix
            ).flatMap({ URL(string: $0) }) ?? fullImageURL
            let width = intValue(in: item, at: mapping.widthPath)
                ?? intValue(in: item, atAny: ["width", "w", "dimension_x", "image.width", "image_width"])
            let height = intValue(in: item, at: mapping.heightPath)
                ?? intValue(in: item, atAny: ["height", "h", "dimension_y", "image.height", "image_height"])
            let resolution: String
            if let width, let height {
                resolution = "\(width)x\(height)"
            } else {
                resolution = "自定义"
            }
            return Wallpaper(
                id: stringValue(in: item, at: mapping.idPath) ?? stringValue(in: item, atAny: ["id", "hsh", "uuid", "key"]) ?? fullImageURL.absoluteString,
                thumbnailURL: thumbnailURL,
                fullImageURL: fullImageURL,
                title: stringValue(in: item, at: mapping.titlePath) ?? stringValue(in: item, atAny: ["title", "name", "copyright", "description"]),
                author: stringValue(in: item, at: mapping.authorPath) ?? stringValue(in: item, atAny: ["author", "uploader.username", "user.name", "username"]),
                resolution: resolution,
                views: intValue(in: item, at: mapping.viewsPath) ?? intValue(in: item, atAny: ["views", "view_count"]) ?? 0,
                favorites: intValue(in: item, at: mapping.favoritesPath) ?? intValue(in: item, atAny: ["favorites", "likes", "like_count"]) ?? 0,
                category: stringValue(in: item, at: mapping.categoryPath) ?? stringValue(in: item, at: "category") ?? "custom",
                purity: stringValue(in: item, at: mapping.purityPath) ?? stringValue(in: item, at: "purity") ?? "sfw",
                fileSize: intValue(in: item, at: mapping.fileSizePath) ?? intValue(in: item, atAny: ["file_size", "fileSize", "size"]) ?? 0,
                fileType: stringValue(in: item, at: mapping.fileTypePath) ?? stringValue(in: item, atAny: ["file_type", "fileType", "type", "mime"]) ?? fullImageURL.pathExtension,
                createdAt: stringValue(in: item, at: mapping.createdAtPath) ?? stringValue(in: item, atAny: ["created_at", "createdAt", "date", "startdate"]) ?? "",
                colors: stringArrayValue(in: item, at: mapping.colorsPath),
                sourceURL: firstURLValue(in: item, paths: [mapping.sourceURLPath, "source", "source_url", "sourceURL", "url"], prefix: nil).flatMap(URL.init(string:))
            )
        }

        guard !wallpapers.isEmpty || items.isEmpty else {
            throw NetworkError.invalidResponse
        }

        let hasMore = boolValue(in: root, at: mapping.hasMorePath)
        let lastPage = intValue(in: root, at: mapping.lastPagePath)
        let nextPageExists = mapping.nextPagePath.isEmpty ? nil : value(in: root, at: mapping.nextPagePath)
        return (wallpapers, hasMore ?? lastPage.map { page < $0 } ?? nextPageExists.map { _ in true } ?? mapping.defaultHasMore ?? !items.isEmpty)
    }

    private var itemPathCandidates: [String] {
        [mapping.itemsPath, "", "data", "images", "results", "items", "wallpapers", "photos", "data.items", "data.images", "data.results", "response.images"]
            .deduplicatedNonEmptyKeepingRoot()
    }

    private var thumbnailPathCandidates: [String] {
        [
            mapping.thumbnailURLPath,
            "thumbnail", "thumb", "thumb_url", "thumbUrl", "thumbnail_url", "thumbnailUrl",
            "thumbs.large", "thumbs.original", "image.thumbnail", "image.thumb",
            "url", "image", "image_url", "imageUrl", "path", "src", "file", "download_url",
            "data.url", "data.image", "data.imageUrl", "response.url", "response.image", "response.imageUrl"
        ].deduplicatedNonEmptyKeepingRoot()
    }

    private var fullImagePathCandidates: [String] {
        [
            mapping.fullImageURLPath,
            "url", "image", "image_url", "imageUrl", "path", "src", "file", "download_url",
            "full", "full_url", "fullUrl", "original", "original_url", "originalUrl",
            "image.url", "images.0.url",
            "data.url", "data.image", "data.imageUrl", "response.url", "response.image", "response.imageUrl"
        ].deduplicatedNonEmptyKeepingRoot()
    }

    private func itemArray(in root: Any) -> [Any]? {
        for path in itemPathCandidates {
            if path.isEmpty, let array = root as? [Any] {
                return array
            }
            if let array = value(in: root, at: path) as? [Any] {
                return array
            }
        }
        if let dictionary = root as? [String: Any],
           dictionary.values.count == 1,
           let array = dictionary.values.first as? [Any] {
            return array
        }
        if firstURLValue(in: root, paths: fullImagePathCandidates, prefix: mapping.fullImageURLPrefix) != nil {
            return [root]
        }
        return nil
    }

    private func value(in root: Any, at path: String) -> Any? {
        guard !path.isEmpty else { return nil }
        var current: Any? = root
        for component in path.split(separator: ".") {
            guard let unwrapped = current else { return nil }
            if let dictionary = unwrapped as? [String: Any] {
                current = dictionary[String(component)]
                continue
            }
            if let array = unwrapped as? [Any], let index = Int(component), array.indices.contains(index) {
                current = array[index]
                continue
            }
            return nil
        }
        return current
    }

    private func urlStringValue(in root: Any, at path: String, prefix: String?) -> String? {
        guard let rawValue = stringValue(in: root, at: path) else { return nil }
        return normalizedURLString(rawValue, prefix: prefix)
    }

    private func firstURLValue(in root: Any, paths: [String], prefix: String?) -> String? {
        for path in paths {
            if let value = urlStringValue(in: root, at: path, prefix: prefix) {
                return value
            }
        }
        return nil
    }

    private func normalizedURLString(_ rawValue: String, prefix: String?) -> String? {
        if rawValue.contains("://") {
            return rawValue
        }
        if rawValue.hasPrefix("//") {
            return "https:\(rawValue)"
        }
        guard let prefix, !prefix.isEmpty else {
            return rawValue
        }
        if rawValue.hasPrefix("/") {
            return prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + rawValue
        }
        return prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + rawValue
    }

    private func stringValue(in root: Any, at path: String) -> String? {
        guard let rawValue = value(in: root, at: path) else { return nil }
        if let string = rawValue as? String { return string }
        if let number = rawValue as? NSNumber { return number.stringValue }
        return nil
    }

    private func intValue(in root: Any, at path: String) -> Int? {
        guard let rawValue = value(in: root, at: path) else { return nil }
        if let int = rawValue as? Int { return int }
        if let number = rawValue as? NSNumber { return number.intValue }
        if let string = rawValue as? String { return Int(string) }
        return nil
    }

    private func intValue(in root: Any, atAny paths: [String]) -> Int? {
        for path in paths {
            if let value = intValue(in: root, at: path) {
                return value
            }
        }
        return nil
    }

    private func stringValue(in root: Any, atAny paths: [String]) -> String? {
        for path in paths {
            if let value = stringValue(in: root, at: path), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func boolValue(in root: Any, at path: String) -> Bool? {
        guard let rawValue = value(in: root, at: path) else { return nil }
        if let bool = rawValue as? Bool { return bool }
        if let number = rawValue as? NSNumber { return number.boolValue }
        if let string = rawValue as? String {
            switch string.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private func stringArrayValue(in root: Any, at path: String) -> [String] {
        guard let rawValue = value(in: root, at: path) else { return [] }
        if let strings = rawValue as? [String] { return strings }
        if let values = rawValue as? [Any] {
            return values.compactMap {
                if let string = $0 as? String { return string }
                if let number = $0 as? NSNumber { return number.stringValue }
                return nil
            }
        }
        return []
    }
}

private extension Array where Element == String {
    func deduplicatedNonEmptyKeepingRoot() -> [String] {
        var seen = Set<String>()
        var values: [String] = []
        for value in self {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty || seen.insert(trimmed).inserted else { continue }
            values.append(trimmed)
        }
        return values
    }
}
