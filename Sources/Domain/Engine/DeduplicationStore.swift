import Foundation

@MainActor
final class DeduplicationStore {
    private var seenIDs = Set<String>()

    var count: Int { seenIDs.count }

    func contains(_ id: String) -> Bool {
        seenIDs.contains(id)
    }

    func insert(_ id: String) {
        seenIDs.insert(id)
    }

    func insertBatch(_ ids: [String]) {
        seenIDs.formUnion(ids)
    }

    func filterNew(from items: [Wallpaper]) -> [Wallpaper] {
        items.filter { !seenIDs.contains($0.id) }
    }

    func reset() {
        seenIDs.removeAll()
    }
}
