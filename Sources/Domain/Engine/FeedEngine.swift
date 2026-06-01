import Foundation

@MainActor
@Observable
final class FeedEngine {
    private let repository: WallpaperRepository
    private let sourceConfigurationStore: WallhavenSourceConfigurationStore
    private let sourceEngineStore: WallpaperSourceEngineStore
    private let pagination: PaginationController
    private let prefetchController: PrefetchController
    private let dedup: DeduplicationStore

    private(set) var wallpapers: [Wallpaper] = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var error: NetworkError?
    private(set) var currentSorting: WallhavenSorting = .toplist
    private(set) var currentQuery = ""
    private(set) var sourceConfiguration: WallhavenSourceConfiguration
    private(set) var sourceEngines: [WallpaperSourceEngine]
    private(set) var activeSourceEngineID: UUID

    var hasMore: Bool { pagination.hasMore }
    var activeSourceEngine: WallpaperSourceEngine {
        sourceEngines.first(where: { $0.id == activeSourceEngineID }) ?? sourceEngines[0]
    }
    private var currentTask: Task<Void, Never>?
    private var didLoadInitialPage = false
    private var refreshGeneration = 0

    init(
        repository: WallpaperRepository = WallpaperRepository(),
        sourceConfigurationStore: WallhavenSourceConfigurationStore = WallhavenSourceConfigurationStore(),
        sourceEngineStore: WallpaperSourceEngineStore = WallpaperSourceEngineStore()
    ) {
        self.repository = repository
        self.sourceConfigurationStore = sourceConfigurationStore
        self.sourceEngineStore = sourceEngineStore
        self.sourceConfiguration = sourceConfigurationStore.load()
        let loadedSourceEngines = sourceEngineStore.loadEngines()
        self.sourceEngines = loadedSourceEngines
        self.activeSourceEngineID = sourceEngineStore.loadActiveEngineID(engines: loadedSourceEngines)
        self.pagination = PaginationController()
        self.prefetchController = PrefetchController(threshold: 6)
        self.dedup = DeduplicationStore()
    }

    // MARK: - Public API

    func loadInitialPageIfNeeded() async {
        guard !didLoadInitialPage else { return }
        didLoadInitialPage = true
        await refresh()
    }

    func refresh() async {
        currentTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true
        error = nil
        resetState()

        currentTask = Task { [weak self] in
            guard let self = self else { return }
            await self.executeFetch(page: 1)
        }
        let task = currentTask
        await task?.value
        if refreshGeneration == generation {
            isRefreshing = false
        }
    }

    func loadNextPage() async {
        guard pagination.hasMore, !isLoading, !isRefreshing else { return }
        isLoading = true
        error = nil
        await executeFetch(page: pagination.nextPage)
        isLoading = false
    }

    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery != currentQuery else { return }
        currentQuery = trimmedQuery
        await refresh()
    }

    func updateSorting(_ sorting: WallhavenSorting) async {
        guard sorting != currentSorting else { return }
        currentSorting = sorting
        await refresh()
    }

    func updateSourceConfiguration(_ configuration: WallhavenSourceConfiguration) async {
        guard configuration != sourceConfiguration else { return }
        sourceConfiguration = configuration
        sourceConfigurationStore.save(configuration)
        if activeSourceEngine.supportsWallhavenFilters {
            persistWallhavenAPIKey(configuration.trimmedAPIKey)
        }
        await refresh()
    }

    func selectSourceEngine(_ sourceEngine: WallpaperSourceEngine) async {
        guard sourceEngine.id != activeSourceEngineID else { return }
        activeSourceEngineID = sourceEngine.id
        persistSourceEngines()
        await refresh()
    }

    func saveSourceEngine(_ sourceEngine: WallpaperSourceEngine) async {
        if let index = sourceEngines.firstIndex(where: { $0.id == sourceEngine.id }) {
            sourceEngines[index] = sourceEngine
        } else {
            sourceEngines.append(sourceEngine)
            activeSourceEngineID = sourceEngine.id
        }
        persistSourceEngines()
        await refresh()
    }

    func saveSourceEngines(_ importedEngines: [WallpaperSourceEngine]) async {
        guard !importedEngines.isEmpty else { return }
        var firstImportedID: UUID?
        for sourceEngine in importedEngines {
            if let index = sourceEngines.firstIndex(where: { $0.name == sourceEngine.name }) {
                var updatedSource = sourceEngine
                updatedSource.id = sourceEngines[index].id
                if updatedSource.trimmedAPIKey.isEmpty {
                    updatedSource.apiKey = sourceEngines[index].apiKey
                }
                sourceEngines[index] = updatedSource
                firstImportedID = firstImportedID ?? updatedSource.id
            } else {
                sourceEngines.append(sourceEngine)
                firstImportedID = firstImportedID ?? sourceEngine.id
            }
        }
        activeSourceEngineID = firstImportedID ?? activeSourceEngineID
        persistSourceEngines()
        await refresh()
    }

    func deleteSourceEngine(_ sourceEngine: WallpaperSourceEngine) async {
        guard sourceEngines.count > 1 else { return }
        sourceEngines.removeAll { $0.id == sourceEngine.id }
        sourceEngineStore.deleteSecrets(for: sourceEngine)
        if activeSourceEngineID == sourceEngine.id {
            activeSourceEngineID = sourceEngines.first?.id ?? WallpaperSourceEngine.wallhavenTemplateID
        }
        persistSourceEngines()
        await refresh()
    }

    func prefetchIfNeeded(currentIndex: Int) {
        guard prefetchController.shouldPrefetch(currentIndex: currentIndex, totalCount: wallpapers.count) else { return }
        Task { [weak self] in
            await self?.loadNextPage()
            await self?.prefetchController.prefetchCompleted()
        }
    }

    func prefetchImages(for urls: [URL], using loader: ImageLoader) {
        Task { await loader.prefetchImages(urls: urls) }
    }

    // MARK: - Private

    private func resetState() {
        pagination.reset()
        prefetchController.reset()
        dedup.reset()
    }

    private func executeFetch(page: Int) async {
        do {
            let result = try await repository.fetchWallpapers(
                query: currentQuery, page: page,
                sorting: currentSorting, configuration: sourceConfiguration,
                sourceEngine: activeSourceEngine
            )
            guard !Task.isCancelled else { return }

            let newItems = dedup.filterNew(from: result.wallpapers)
            dedup.insertBatch(newItems.map(\.id))
            pagination.markPageLoaded(page: page, hasMore: result.hasMore)

            if page == 1 {
                wallpapers = newItems
            } else {
                wallpapers.append(contentsOf: newItems)
            }
            error = nil
        } catch let error as NetworkError {
            guard !Task.isCancelled else { return }
            self.error = error
        } catch {
            guard !Task.isCancelled else { return }
            self.error = .invalidResponse
        }
    }

    private func persistSourceEngines() {
        sourceEngineStore.save(engines: sourceEngines, activeEngineID: activeSourceEngineID)
    }

    private func persistWallhavenAPIKey(_ apiKey: String) {
        guard let index = sourceEngines.firstIndex(where: { $0.id == activeSourceEngineID }) else { return }
        sourceEngines[index].apiKey = apiKey
        persistSourceEngines()
    }
}
