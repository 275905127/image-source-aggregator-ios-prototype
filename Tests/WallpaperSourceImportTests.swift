import XCTest
@testable import Wallhaven

final class WallpaperSourceImportTests: XCTestCase {
    func testImportsWallhavenSimplifiedConfigurationWithKeyStoredSeparately() throws {
        let json = """
        {
          "name": "Wallhaven",
          "type": "api",
          "url": "https://wallhaven.cc/api/v1/search",
          "enabled": true,
          "params": {
            "apikey": "secret-key",
            "categories": "111",
            "purity": "100"
          }
        }
        """

        let source = try XCTUnwrap(WallpaperSourceImporter.importSources(from: json).first)
        XCTAssertEqual(source.name, "Wallhaven")
        XCTAssertEqual(source.apiKey, "secret-key")
        XCTAssertFalse(source.request.staticQueryItems.contains { $0.name == "apikey" })
        XCTAssertEqual(source.mapping.itemsPath, "data")
        XCTAssertEqual(source.mapping.fullImageURLPath, "path")
        XCTAssertTrue(source.supportsWallhavenFilters)
    }

    func testWallhavenEndpointUsesConfiguredFilterAndAPIKeyNames() throws {
        let json = """
        {
          "name": "Wallhaven",
          "type": "api",
          "url": "https://wallhaven.cc/api/v1/search",
          "params": {
            "apikey": "secret-key",
            "atleast": "1920x1080",
            "purity": "100"
          }
        }
        """

        let source = try XCTUnwrap(WallpaperSourceImporter.importSources(from: json).first)
        var configuration = WallhavenSourceConfiguration()
        configuration.categories = [.anime]
        configuration.purities = [.sfw, .sketchy]
        configuration.order = .ascending
        let endpoint = Endpoint.search(
            query: "city",
            page: 2,
            sorting: .dateAdded,
            configuration: configuration,
            sourceEngine: source
        )
        let queryItems = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(queryItems["q"], "city")
        XCTAssertEqual(queryItems["page"], "2")
        XCTAssertEqual(queryItems["sorting"], "date_added")
        XCTAssertEqual(queryItems["categories"], "010")
        XCTAssertEqual(queryItems["purity"], "110")
        XCTAssertEqual(queryItems["order"], "asc")
        XCTAssertEqual(queryItems["apikey"], "secret-key")
        XCTAssertEqual(queryItems["atleast"], "1920x1080")
    }

    func testEncodedSourceDoesNotPersistAPIKey() throws {
        let source = WallpaperSourceEngine(
            name: "Private API",
            kind: .jsonAPI,
            request: SourceEngineRequest(baseURL: "https://example.com", pathTemplate: "/images"),
            apiKey: "secret-key"
        )

        let data = try JSONEncoder().encode(source)
        let encoded = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(encoded.contains("secret-key"))
    }

    func testImportsHeaderSecretWithoutPersistingPlainHeader() throws {
        let json = """
        {
          "name": "Header API",
          "type": "json",
          "request": {
            "url": "https://example.com/images",
            "headers": {
              "Authorization": "Bearer header-secret",
              "Accept": "application/json"
            }
          },
          "mapping": {
            "items": "data",
            "image": "url"
          }
        }
        """

        let source = try XCTUnwrap(WallpaperSourceImporter.importSources(from: json).first)
        XCTAssertEqual(source.apiKey, "header-secret")
        XCTAssertEqual(source.request.apiKeyPlacement, .bearer)
        XCTAssertEqual(source.request.apiKeyQueryName, "Authorization")
        XCTAssertEqual(source.request.staticHeaders.map(\.name), ["Accept"])
    }

    func testBingConfigurationUsesKnownMappingAndNoPagination() throws {
        let json = """
        {
          "name": "Bing Wallpaper",
          "type": "json",
          "url": "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8",
          "enabled": true
        }
        """

        let source = try XCTUnwrap(WallpaperSourceImporter.importSources(from: json).first)
        XCTAssertEqual(source.mapping.itemsPath, "images")
        XCTAssertEqual(source.mapping.fullImageURLPrefix, "https://www.bing.com")
        let response: [String: Any] = [
            "images": [
                [
                    "hsh": "abc",
                    "url": "/th?id=1.jpg",
                    "copyright": "Bing image"
                ]
            ]
        ]
        let result = try source.decodeWallpapers(from: response, page: 1)
        XCTAssertEqual(result.wallpapers.first?.fullImageURL.absoluteString, "https://www.bing.com/th?id=1.jpg")
        XCTAssertFalse(result.hasMore)
    }

    func testAutoMappingDecodesRootArrayAndSingleObject() throws {
        let source = WallpaperSourceEngine(
            name: "Auto",
            kind: .jsonAPI,
            request: SourceEngineRequest(baseURL: "https://example.com", pathTemplate: "/images"),
            mapping: SourceEngineMapping(defaultHasMore: false)
        )

        let arrayResult = try source.decodeWallpapers(from: [["url": "https://example.com/a.jpg", "width": 1920, "height": 1080]], page: 1)
        XCTAssertEqual(arrayResult.wallpapers.count, 1)
        XCTAssertEqual(arrayResult.wallpapers[0].resolution, "1920x1080")

        let objectResult = try source.decodeWallpapers(from: ["url": "https://example.com/b.jpg"], page: 1)
        XCTAssertEqual(objectResult.wallpapers.count, 1)
        XCTAssertEqual(objectResult.wallpapers[0].fullImageURL.absoluteString, "https://example.com/b.jpg")
    }

    func testAutoMappingDecodesNestedSingleObjectURL() throws {
        let source = WallpaperSourceEngine(
            name: "Random API",
            kind: .jsonAPI,
            request: SourceEngineRequest(baseURL: "https://example.com", pathTemplate: "/random"),
            mapping: SourceEngineMapping(defaultHasMore: false)
        )

        let result = try source.decodeWallpapers(from: ["data": ["url": "https://example.com/random.jpg"]], page: 1)
        XCTAssertEqual(result.wallpapers.count, 1)
        XCTAssertEqual(result.wallpapers[0].fullImageURL.absoluteString, "https://example.com/random.jpg")
        XCTAssertFalse(result.hasMore)
    }

    func testPaginationSupportsBooleanAndLastPagePaths() throws {
        var booleanMapping = SourceEngineMapping()
        booleanMapping.hasMorePath = "has_more"
        let booleanSource = WallpaperSourceEngine(
            name: "Boolean",
            kind: .jsonAPI,
            request: SourceEngineRequest(baseURL: "https://example.com", pathTemplate: "/images"),
            mapping: booleanMapping
        )

        let booleanResponse: [String: Any] = [
            "data": [["url": "https://example.com/a.jpg"]],
            "has_more": false
        ]
        XCTAssertFalse(try booleanSource.decodeWallpapers(from: booleanResponse, page: 1).hasMore)

        var lastPageMapping = SourceEngineMapping()
        lastPageMapping.lastPagePath = "meta.last_page"
        let lastPageSource = WallpaperSourceEngine(
            name: "Last Page",
            kind: .jsonAPI,
            request: SourceEngineRequest(baseURL: "https://example.com", pathTemplate: "/images"),
            mapping: lastPageMapping
        )
        let lastPageResponse: [String: Any] = [
            "data": [["url": "https://example.com/a.jpg"]],
            "meta": ["last_page": 3]
        ]
        XCTAssertTrue(try lastPageSource.decodeWallpapers(from: lastPageResponse, page: 2).hasMore)
        XCTAssertFalse(try lastPageSource.decodeWallpapers(from: lastPageResponse, page: 3).hasMore)
    }
}
