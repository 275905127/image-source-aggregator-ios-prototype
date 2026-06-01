import UIKit
import CryptoKit

final class DiskImageCache {
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let maxCacheSize: Int
    private let ttl: TimeInterval
    private let ioQueue = DispatchQueue(label: "com.wallhaven.diskcache", qos: .utility)
    private(set) var stats = CacheStats()

    init(maxCacheSize: Int = 500 * 1024 * 1024, ttl: TimeInterval = 3600) {
        self.fileManager = FileManager.default
        self.maxCacheSize = maxCacheSize
        self.ttl = ttl
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("WallhavenImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        performCleanupIfNeeded()
    }

    func image(for url: URL) -> UIImage? {
        image(forKey: url.absoluteString)
    }

    func image(forKey key: String) -> UIImage? {
        let fileURL = cacheFileURL(forKey: key)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            stats.misses += 1
            return nil
        }
        if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(modDate) > ttl {
            try? fileManager.removeItem(at: fileURL)
            stats.misses += 1
            return nil
        }
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            stats.misses += 1
            return nil
        }
        stats.hits += 1
        updateAccessDate(for: fileURL)
        return image
    }

    func storeImage(_ image: UIImage, for url: URL) {
        storeImage(image, forKey: url.absoluteString)
    }

    func storeImage(_ image: UIImage, forKey key: String) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.cacheFileURL(forKey: key)
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: fileURL, options: .atomic)
                self.performCleanupIfNeeded()
            }
        }
    }

    func removeAll() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Private

    private func cacheFileURL(for url: URL) -> URL {
        cacheFileURL(forKey: url.absoluteString)
    }

    private func cacheFileURL(forKey key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8))
        let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(filename)
    }

    private func updateAccessDate(for url: URL) {
        try? (url as NSURL).setResourceValue(Date(), forKey: .contentAccessDateKey)
    }

    private func performCleanupIfNeeded() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let contents = try? self.fileManager.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey],
                options: .skipsHiddenFiles
            ) else { return }
            let totalSize = contents.reduce(0) { sum, url in
                sum + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            guard totalSize > self.maxCacheSize else { return }
            let sorted = contents.sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
                return dateA < dateB
            }
            var freed = 0
            let target = self.maxCacheSize / 2
            for url in sorted {
                guard totalSize - freed > target else { break }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                try? self.fileManager.removeItem(at: url)
                freed += size
            }
        }
    }
}
