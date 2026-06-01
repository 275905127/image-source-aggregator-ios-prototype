import SwiftUI

@MainActor
@Observable
final class BrowseViewModel {
    private let feedEngine: FeedEngine
    let imageLoader: ImageLoader

    var wallpapers: [Wallpaper] { feedEngine.wallpapers }
    var isLoading: Bool { feedEngine.isLoading }
    var isRefreshing: Bool { feedEngine.isRefreshing }
    var error: NetworkError? { feedEngine.error }
    var sortingOptions: [WallhavenSorting] { WallhavenSorting.allCases }
    var currentSorting: WallhavenSorting { feedEngine.currentSorting }
    var currentQuery: String { feedEngine.currentQuery }
    var sourceConfiguration: WallhavenSourceConfiguration { feedEngine.sourceConfiguration }
    var sourceEngines: [WallpaperSourceEngine] { feedEngine.sourceEngines }
    var activeSourceEngine: WallpaperSourceEngine { feedEngine.activeSourceEngine }
    var categoryOptions: [WallhavenCategory] { WallhavenCategory.allCases }
    var purityOptions: [WallhavenPurity] { WallhavenPurity.allCases }
    var orderOptions: [WallhavenOrder] { WallhavenOrder.allCases }
    var topRangeOptions: [WallhavenTopRange] { WallhavenTopRange.allCases }

    init(feedEngine: FeedEngine, imageLoader: ImageLoader) {
        self.feedEngine = feedEngine
        self.imageLoader = imageLoader
    }

    func onAppear() async {
        await feedEngine.loadInitialPageIfNeeded()
    }

    func onRefresh() async {
        await feedEngine.refresh()
    }

    func onItemAppear(index: Int) {
        feedEngine.prefetchIfNeeded(currentIndex: index)
    }

    func onSearchDebounced(query: String, searchTask: inout Task<Void, Never>?) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await feedEngine.search(query: query)
        }
    }

    func onSortSelected(_ sorting: WallhavenSorting) async {
        await feedEngine.updateSorting(sorting)
    }

    func onCategoryToggled(_ category: WallhavenCategory) async {
        var configuration = sourceConfiguration
        configuration.toggleCategory(category)
        await feedEngine.updateSourceConfiguration(configuration)
    }

    func onPurityToggled(_ purity: WallhavenPurity) async {
        var configuration = sourceConfiguration
        configuration.togglePurity(purity)
        await feedEngine.updateSourceConfiguration(configuration)
    }

    func onOrderSelected(_ order: WallhavenOrder) async {
        var configuration = sourceConfiguration
        configuration.order = order
        await feedEngine.updateSourceConfiguration(configuration)
    }

    func onTopRangeSelected(_ topRange: WallhavenTopRange) async {
        var configuration = sourceConfiguration
        configuration.topRange = topRange
        await feedEngine.updateSourceConfiguration(configuration)
    }

    func onAPIKeyChanged(_ apiKey: String) async {
        var configuration = sourceConfiguration
        configuration.setAPIKey(apiKey)
        await feedEngine.updateSourceConfiguration(configuration)
    }

    func onSourceSelected(_ sourceEngine: WallpaperSourceEngine) async {
        await feedEngine.selectSourceEngine(sourceEngine)
    }

    func onSourceSaved(_ sourceEngine: WallpaperSourceEngine) async {
        await feedEngine.saveSourceEngine(sourceEngine)
    }

    func onSourcesImported(_ sourceEngines: [WallpaperSourceEngine]) async {
        await feedEngine.saveSourceEngines(sourceEngines)
    }

    func onSourceDeleted(_ sourceEngine: WallpaperSourceEngine) async {
        await feedEngine.deleteSourceEngine(sourceEngine)
    }

    func prefetchImages(for items: [Wallpaper]) {
        let urls = items.map(\.thumbnailURL)
        Task { await imageLoader.prefetchImages(urls: urls) }
    }

    func loadImage(from url: URL) async -> UIImage? {
        await imageLoader.loadImage(from: url)
    }

    func loadThumbnail(from url: URL, targetPixelSize: CGSize) async -> UIImage? {
        await imageLoader.loadImage(from: url, targetPixelSize: targetPixelSize)
    }
}
