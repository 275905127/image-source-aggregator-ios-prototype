import UIKit

struct CacheStats {
    var hits: Int = 0
    var misses: Int = 0

    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }
}

final class MemoryImageCache {
    private let cache = NSCache<NSString, CacheEntry>()
    private var accessOrder: [NSString] = []
    private let maxCount: Int
    let ttl: TimeInterval
    private(set) var stats = CacheStats()

    init(countLimit: Int = 300, totalCostLimit: Int = 200 * 1024 * 1024, ttl: TimeInterval = 600) {
        self.maxCount = countLimit
        self.ttl = ttl
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func image(for url: URL) -> UIImage? {
        image(forKey: url.absoluteString)
    }

    func image(forKey key: String) -> UIImage? {
        let cacheKey = key as NSString
        guard let entry = cache.object(forKey: cacheKey) else {
            stats.misses += 1
            return nil
        }
        if Date().timeIntervalSince(entry.createdAt) > ttl {
            removeImage(forKey: key)
            stats.misses += 1
            return nil
        }
        stats.hits += 1
        touchAccessOrder(cacheKey)
        return entry.image
    }

    func setImage(_ image: UIImage, for url: URL) {
        setImage(image, forKey: url.absoluteString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let key = key as NSString
        let entry = CacheEntry(image: image, createdAt: Date())
        cache.setObject(entry, forKey: key, cost: image.memoryCost)
        touchAccessOrder(key)
        evictIfNeeded()
    }

    func removeImage(for url: URL) {
        removeImage(forKey: url.absoluteString)
    }

    func removeImage(forKey key: String) {
        let key = key as NSString
        cache.removeObject(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    func removeAll() {
        cache.removeAllObjects()
        accessOrder.removeAll()
    }

    // MARK: Private

    private func touchAccessOrder(_ key: NSString) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded() {
        while accessOrder.count > maxCount {
            let oldest = accessOrder.removeFirst()
            cache.removeObject(forKey: oldest)
        }
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return max(1, cgImage.bytesPerRow * cgImage.height)
    }
}

private final class CacheEntry {
    let image: UIImage
    let createdAt: Date

    init(image: UIImage, createdAt: Date) {
        self.image = image
        self.createdAt = createdAt
    }
}
