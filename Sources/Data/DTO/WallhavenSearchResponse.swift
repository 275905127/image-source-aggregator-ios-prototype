import Foundation

struct WallhavenSearchResponse: Decodable {
    let data: [WallpaperDTO]
    let meta: WallhavenMeta
}

struct WallhavenMeta: Decodable {
    let currentPage: Int
    let lastPage: Int
    let perPage: Int
    let total: Int
    let query: String?
    let seed: String?
}

struct WallpaperDTO: Decodable {
    let id: String
    let url: String
    let shortUrl: String
    let views: Int
    let favorites: Int
    let source: String
    let purity: String
    let category: String
    let dimensionX: Int
    let dimensionY: Int
    let resolution: String
    let ratio: String
    let fileSize: Int
    let fileType: String
    let createdAt: String
    let colors: [String]
    let path: String
    let thumbs: WallhavenThumbs
    let uploader: WallhavenUploader?
    let tags: [WallhavenTag]?
}

struct WallhavenThumbs: Decodable {
    let large: String
    let original: String
    let small: String
}

struct WallhavenUploader: Decodable {
    let username: String
    let group: String?
}

struct WallhavenTag: Decodable {
    let id: Int
    let name: String
    let alias: String?
    let categoryId: Int?
    let category: String?
    let purity: String?
    let createdAt: String?
}
