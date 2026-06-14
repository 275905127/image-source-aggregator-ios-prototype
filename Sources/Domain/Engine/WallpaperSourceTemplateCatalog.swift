import Foundation

enum WallpaperSourceTemplateCatalog {
    static let bingTemplateID = UUID(uuidString: "2C3AF730-28F5-4CA7-8F81-18244C6B1A3A")!
    static let picsumTemplateID = UUID(uuidString: "D1646636-41F0-4544-96E5-C20DF22972C1")!

    static var defaultTemplateIDs: Set<UUID> {
        [WallpaperSourceEngine.wallhavenTemplateID, bingTemplateID, picsumTemplateID]
    }

    static var defaultEngines: [WallpaperSourceEngine] {
        [
            .wallhavenTemplate,
            bingWallpaper,
            picsumPhotos
        ]
    }

    static var addableTemplates: [WallpaperSourceEngine] {
        [
            blankJSONAPI,
            blankDirectLinks,
            .wallhavenTemplate,
            bingWallpaper,
            picsumPhotos
        ]
    }

    static func mergeMissingDefaults(into engines: [WallpaperSourceEngine]) -> [WallpaperSourceEngine] {
        var merged = engines
        for template in defaultEngines {
            let hasTemplate = merged.contains { source in
                source.id == template.id || source.name.caseInsensitiveCompare(template.name) == .orderedSame
            }
            if !hasTemplate {
                merged.append(template)
            }
        }
        return merged
    }

    static var bingWallpaper: WallpaperSourceEngine {
        WallpaperSourceEngine(
            id: bingTemplateID,
            name: "Bing Wallpaper",
            kind: .jsonAPI,
            request: SourceEngineRequest(
                baseURL: "https://www.bing.com",
                pathTemplate: "/HPImageArchive.aspx",
                pageQueryName: "",
                searchQueryName: "",
                staticQueryItems: [
                    SourceEngineQueryItem(name: "format", value: "js"),
                    SourceEngineQueryItem(name: "idx", value: "0"),
                    SourceEngineQueryItem(name: "n", value: "8")
                ]
            ),
            mapping: SourceEngineMapping(
                itemsPath: "images",
                idPath: "hsh",
                thumbnailURLPath: "url",
                fullImageURLPath: "url",
                thumbnailURLPrefix: "https://www.bing.com",
                fullImageURLPrefix: "https://www.bing.com",
                titlePath: "copyright",
                sourceURLPath: "copyrightlink",
                defaultHasMore: false
            )
        )
    }

    static var picsumPhotos: WallpaperSourceEngine {
        WallpaperSourceEngine(
            id: picsumTemplateID,
            name: "Lorem Picsum",
            kind: .jsonAPI,
            request: SourceEngineRequest(
                baseURL: "https://picsum.photos",
                pathTemplate: "/v2/list",
                pageQueryName: "page",
                searchQueryName: "",
                staticQueryItems: [
                    SourceEngineQueryItem(name: "limit", value: "60")
                ]
            ),
            mapping: SourceEngineMapping(
                itemsPath: "$",
                idPath: "id",
                thumbnailURLPath: "download_url",
                fullImageURLPath: "download_url",
                titlePath: "author",
                authorPath: "author",
                widthPath: "width",
                heightPath: "height",
                sourceURLPath: "url",
                defaultHasMore: true
            )
        )
    }

    static var blankJSONAPI: WallpaperSourceEngine {
        WallpaperSourceEngine(
            name: "新 JSON API 图源",
            kind: .jsonAPI,
            request: SourceEngineRequest(
                baseURL: "https://example.com",
                pathTemplate: "/images",
                pageQueryName: "page",
                searchQueryName: "q"
            ),
            mapping: SourceEngineMapping(
                itemsPath: "data",
                idPath: "id",
                thumbnailURLPath: "thumbnail",
                fullImageURLPath: "url",
                titlePath: "title",
                defaultHasMore: true
            )
        )
    }

    static var blankDirectLinks: WallpaperSourceEngine {
        WallpaperSourceEngine(
            name: "新图片直链图源",
            kind: .directLinks,
            directImages: [
                "https://picsum.photos/seed/wallhaven-ios-1/1600/2400",
                "https://picsum.photos/seed/wallhaven-ios-2/1600/2200"
            ]
        )
    }
}

extension WallpaperSourceEngine {
    var isBuiltInTemplate: Bool {
        WallpaperSourceTemplateCatalog.defaultTemplateIDs.contains(id)
    }

    func duplicatedForEditing(nameSuffix: String = "副本") -> WallpaperSourceEngine {
        var copy = self
        copy.id = UUID()
        copy.name = "\(name) \(nameSuffix)"
        return copy
    }
}
