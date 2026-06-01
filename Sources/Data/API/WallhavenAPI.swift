import Foundation

final class WallhavenAPI {
    private let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    func search(
        query: String,
        page: Int,
        sorting: WallhavenSorting,
        configuration: WallhavenSourceConfiguration,
        sourceEngine: WallpaperSourceEngine
    ) async throws -> WallhavenSearchResponse {
        let endpoint = Endpoint.search(
            query: query,
            page: page,
            sorting: sorting,
            configuration: configuration,
            sourceEngine: sourceEngine
        )
        return try await client.request(endpoint)
    }
}
