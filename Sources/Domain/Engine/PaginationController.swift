import Foundation

@MainActor
final class PaginationController {
    private(set) var currentPage = 0
    private(set) var hasMore = true

    var nextPage: Int { currentPage + 1 }

    func markPageLoaded(page: Int, hasMore: Bool) {
        currentPage = page
        self.hasMore = hasMore
    }

    func reset() {
        currentPage = 0
        hasMore = true
    }
}
