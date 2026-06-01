import Foundation

@MainActor
final class PrefetchController {
    private let threshold: Int
    private var lastPrefetchIndex: Int = -1
    private var isPrefetching = false

    init(threshold: Int = 6) {
        self.threshold = threshold
    }

    func shouldPrefetch(currentIndex: Int, totalCount: Int) -> Bool {
        guard !isPrefetching else { return false }
        let triggerIndex = totalCount - threshold
        guard currentIndex >= triggerIndex, currentIndex > lastPrefetchIndex else { return false }
        lastPrefetchIndex = currentIndex
        isPrefetching = true
        return true
    }

    func prefetchCompleted() {
        isPrefetching = false
    }

    func prefetchCancelled() {
        isPrefetching = false
        lastPrefetchIndex = -1
    }

    func reset() {
        lastPrefetchIndex = -1
        isPrefetching = false
    }
}
