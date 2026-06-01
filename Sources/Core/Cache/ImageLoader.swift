import ImageIO
import UIKit

actor ImageLoader {
    private let memoryCache: MemoryImageCache
    private let diskCache: DiskImageCache
    private let urlSession: URLSession
    private var runningTasks: [String: Task<UIImage?, Never>] = [:]

    var memoryStats: CacheStats { memoryCache.stats }
    var diskStats: CacheStats { diskCache.stats }

    init(
        memoryCache: MemoryImageCache = MemoryImageCache(),
        diskCache: DiskImageCache = DiskImageCache(),
        urlSession: URLSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.urlCache = nil
            return URLSession(configuration: config)
        }()
    ) {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.urlSession = urlSession
    }

    func loadImage(from url: URL) async -> UIImage? {
        await loadImage(from: url, targetPixelSize: nil)
    }

    func loadImage(from url: URL, targetPixelSize: CGSize?) async -> UIImage? {
        let cacheKey = cacheKey(for: url, targetPixelSize: targetPixelSize)
        if let cached = memoryCache.image(forKey: cacheKey) {
            return cached
        }
        if let diskImage = diskCache.image(forKey: cacheKey) {
            memoryCache.setImage(diskImage, forKey: cacheKey)
            return diskImage
        }
        if let existing = runningTasks[cacheKey] {
            return await existing.value
        }
        return await downloadImage(from: url, cacheKey: cacheKey, targetPixelSize: targetPixelSize)
    }

    func prefetchImages(urls: [URL]) {
        for url in urls {
            Task { [weak self] in
                _ = await self?.loadImage(from: url)
            }
        }
    }

    func cancelPrefetch(for urls: [URL]) {
        for url in urls {
            let key = cacheKey(for: url, targetPixelSize: nil)
            runningTasks[key]?.cancel()
            runningTasks[key] = nil
        }
    }

    func clearMemoryCache() {
        memoryCache.removeAll()
    }

    func clearAllCache() {
        memoryCache.removeAll()
        diskCache.removeAll()
    }

    private func downloadImage(from url: URL, cacheKey: String, targetPixelSize: CGSize?) async -> UIImage? {
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            do {
                let (data, response) = try await self.urlSession.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let image = Self.image(from: data, targetPixelSize: targetPixelSize) else {
                    return nil
                }
                await self.memoryCache.setImage(image, forKey: cacheKey)
                await self.diskCache.storeImage(image, forKey: cacheKey)
                return image
            } catch {
                guard !Task.isCancelled else { return nil }
                return nil
            }
        }
        runningTasks[cacheKey] = task
        let result = await task.value
        runningTasks[cacheKey] = nil
        return result
    }

    private func cacheKey(for url: URL, targetPixelSize: CGSize?) -> String {
        guard let targetPixelSize else { return url.absoluteString }
        let width = Int(targetPixelSize.width.rounded(.up))
        let height = Int(targetPixelSize.height.rounded(.up))
        return "\(url.absoluteString)#\(width)x\(height)"
    }

    private static func image(from data: Data, targetPixelSize: CGSize?) -> UIImage? {
        guard let targetPixelSize else {
            return UIImage(data: data)
        }
        let maxDimension = max(targetPixelSize.width, targetPixelSize.height)
        guard maxDimension > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxDimension.rounded(.up)))
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

extension MemoryImageCache: @unchecked Sendable {}
extension DiskImageCache: @unchecked Sendable {}
