import CoreGraphics
import Foundation

struct Wallpaper: Identifiable, Hashable, Sendable {
    let id: String
    let thumbnailURL: URL
    let fullImageURL: URL
    let title: String?
    let author: String?
    let resolution: String
    let views: Int
    let favorites: Int
    let category: String
    let purity: String
    let fileSize: Int
    let fileType: String
    let createdAt: String
    let colors: [String]
    let sourceURL: URL?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Wallpaper, rhs: Wallpaper) -> Bool {
        lhs.id == rhs.id
    }

    var categoryDisplay: String {
        switch category {
        case "general": return "通用"
        case "anime": return "动漫"
        case "people": return "人物"
        default: return category
        }
    }

    var purityDisplay: String {
        switch purity {
        case "sfw": return "SFW"
        case "sketchy": return "草图"
        case "nsfw": return "NSFW"
        default: return purity
        }
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }

    var formattedViews: String {
        if views >= 10000 {
            return String(format: "%.1f万", Double(views) / 10000)
        }
        return "\(views)"
    }

    var pixelSize: CGSize? {
        let components = resolution
            .lowercased()
            .split(separator: "x", maxSplits: 1)
            .compactMap { Double(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard components.count == 2 else { return nil }
        return CGSize(width: CGFloat(components[0]), height: CGFloat(components[1]))
    }
}
