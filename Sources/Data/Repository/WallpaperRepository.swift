import Foundation

final class WallpaperRepository: @unchecked Sendable {
    private let api: WallhavenAPI
    private let client: HTTPClient

    init(api: WallhavenAPI = WallhavenAPI(), client: HTTPClient = HTTPClient()) {
        self.api = api
        self.client = client
    }

    func fetchWallpapers(
        query: String,
        page: Int,
        sorting: WallhavenSorting,
        configuration: WallhavenSourceConfiguration,
        sourceEngine: WallpaperSourceEngine
    ) async throws -> (wallpapers: [Wallpaper], hasMore: Bool) {
        switch sourceEngine.kind {
        case .wallhaven:
            return try await fetchWallhavenWallpapers(
                query: query,
                page: page,
                sorting: sorting,
                configuration: configuration,
                sourceEngine: sourceEngine
            )
        case .jsonAPI:
            if sourceEngine.supportsWallhavenFilters {
                return try await fetchWallhavenWallpapers(
                    query: query,
                    page: page,
                    sorting: sorting,
                    configuration: configuration,
                    sourceEngine: sourceEngine
                )
            }
            return try await fetchJSONAPIWallpapers(query: query, page: page, sourceEngine: sourceEngine)
        case .directLinks:
            return fetchDirectLinkWallpapers(query: query, page: page, sourceEngine: sourceEngine)
        }
    }

    private func fetchWallhavenWallpapers(
        query: String,
        page: Int,
        sorting: WallhavenSorting,
        configuration: WallhavenSourceConfiguration,
        sourceEngine: WallpaperSourceEngine
    ) async throws -> (wallpapers: [Wallpaper], hasMore: Bool) {
        let response = try await api.search(
            query: query,
            page: page,
            sorting: sorting,
            configuration: configuration,
            sourceEngine: sourceEngine
        )
        let wallpapers = try response.data.map { try $0.toDomain() }
        return (wallpapers, page < response.meta.lastPage)
    }

    private func fetchJSONAPIWallpapers(
        query: String,
        page: Int,
        sourceEngine: WallpaperSourceEngine
    ) async throws -> (wallpapers: [Wallpaper], hasMore: Bool) {
        let endpoint = try sourceEngine.endpoint(query: query, page: page)
        let data = try await client.requestData(endpoint)
        let root = try JSONSerialization.jsonObject(with: data)
        return try sourceEngine.decodeWallpapers(from: root, page: page)
    }

    private func fetchDirectLinkWallpapers(
        query: String,
        page: Int,
        sourceEngine: WallpaperSourceEngine
    ) -> (wallpapers: [Wallpaper], hasMore: Bool) {
        let pageSize = 60
        let allURLs = sourceEngine.directImages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
        let startIndex = max(0, (page - 1) * pageSize)
        guard startIndex < allURLs.count else { return ([], false) }
        let endIndex = min(allURLs.count, startIndex + pageSize)
        let wallpapers = allURLs[startIndex..<endIndex].enumerated().compactMap { offset, rawURL -> Wallpaper? in
            guard let url = URL(string: rawURL) else { return nil }
            return Wallpaper(
                id: "\(sourceEngine.id.uuidString)-\(startIndex + offset)-\(rawURL)",
                thumbnailURL: url,
                fullImageURL: url,
                title: sourceEngine.name,
                author: nil,
                resolution: "自定义",
                views: 0,
                favorites: 0,
                category: "custom",
                purity: "sfw",
                fileSize: 0,
                fileType: url.pathExtension.isEmpty ? "image" : url.pathExtension,
                createdAt: "",
                colors: [],
                sourceURL: url
            )
        }
        return (wallpapers, endIndex < allURLs.count)
    }
}

// MARK: - DTO → Domain mapping

extension WallpaperDTO {
    func toDomain() throws -> Wallpaper {
        guard let thumbnailURL = URL(string: thumbs.large) ?? URL(string: thumbs.original),
              let fullImageURL = URL(string: path) else {
            throw NetworkError.invalidURL
        }

        return Wallpaper(
            id: id,
            thumbnailURL: thumbnailURL,
            fullImageURL: fullImageURL,
            title: tags?.prefix(3).map(\.name).joined(separator: ", "),
            author: uploader?.username,
            resolution: resolution,
            views: views,
            favorites: favorites,
            category: category,
            purity: purity,
            fileSize: fileSize,
            fileType: fileType,
            createdAt: createdAt,
            colors: colors,
            sourceURL: URL(string: source)
        )
    }
}

