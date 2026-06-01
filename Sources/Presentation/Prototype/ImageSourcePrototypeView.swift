import SwiftUI

struct ImageSourcePrototypeView: View {
    @State private var selectedTab: PrototypeTab = .home
    @State private var homePath: [PrototypeRoute] = []
    @State private var searchPath: [PrototypeRoute] = []
    @State private var sourcePath: [PrototypeRoute] = []
    @State private var settingsPath: [PrototypeRoute] = []
    @State private var presentedSheet: PrototypeSheet?
    @State private var searchQuery = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house", value: PrototypeTab.home) {
                NavigationStack(path: $homePath) {
                    HomePrototypeView()
                        .prototypeDestinations()
                }
            }

            Tab(value: PrototypeTab.search, role: .search) {
                NavigationStack(path: $searchPath) {
                    SearchPrototypeView(query: $searchQuery, presentedSheet: $presentedSheet)
                        .prototypeDestinations()
                }
            }

            Tab("图源", systemImage: "square.stack.3d.up", value: PrototypeTab.sources) {
                NavigationStack(path: $sourcePath) {
                    SourceManagementPrototypeView(presentedSheet: $presentedSheet)
                        .prototypeDestinations()
                }
            }

            Tab("设置", systemImage: "gearshape", value: PrototypeTab.settings) {
                NavigationStack(path: $settingsPath) {
                    SettingsPrototypeView()
                        .prototypeDestinations()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .searchable(text: $searchQuery, prompt: "跨图源搜索")
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addSource:
                SourceEditorSheet(mode: .add)
            case .editSource(let source):
                SourceEditorSheet(mode: .edit(source))
            case .searchFilters:
                SearchFilterSheet()
            }
        }
    }
}

private enum PrototypeTab: Hashable {
    case home
    case search
    case sources
    case settings
}

private enum PrototypeRoute: Hashable {
    case detail(String)
    case reader(String)
}

private enum PrototypeSheet: Identifiable, Hashable {
    case addSource
    case editSource(PrototypeSource)
    case searchFilters

    var id: String {
        switch self {
        case .addSource:
            return "add-source"
        case .editSource(let source):
            return "edit-source-\(source.id)"
        case .searchFilters:
            return "search-filters"
        }
    }
}

private extension View {
    func prototypeDestinations() -> some View {
        navigationDestination(for: PrototypeRoute.self) { route in
            switch route {
            case .detail(let itemID):
                PrototypeDetailView(item: PrototypeFixtures.item(id: itemID))
            case .reader(let itemID):
                ImageReaderPrototypeView(item: PrototypeFixtures.item(id: itemID))
            }
        }
    }
}

private struct HomePrototypeView: View {
    @State private var selectedScope: PrototypeSourceScope = .all

    private let items = PrototypeFixtures.feedItems
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("图源筛选", selection: $selectedScope) {
                    ForEach(PrototypeSourceScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: PrototypeRoute.detail(item.id)) {
                            PrototypeItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("收藏", systemImage: "heart") {}
                            Button("稍后浏览", systemImage: "clock") {}
                            Button("隐藏此来源", systemImage: "eye.slash") {}
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
        .navigationTitle("首页")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var filteredItems: [PrototypeFeedItem] {
        switch selectedScope {
        case .all:
            return items
        case .enabled:
            return items.filter { !$0.isLocal }
        case .local:
            return items.filter(\.isLocal)
        }
    }
}

private struct SearchPrototypeView: View {
    @Binding var query: String
    @Binding var presentedSheet: PrototypeSheet?
    @State private var selectedScope: PrototypeSearchScope = .all

    private let history = ["城市夜景", "自然风景", "章节封面", "本地收藏"]
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("图源范围", selection: $selectedScope) {
                    ForEach(PrototypeSearchScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if query.isEmpty {
                    SearchHistorySection(history: history) { term in
                        query = term
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(results) { item in
                        NavigationLink(value: PrototypeRoute.detail(item.id)) {
                            PrototypeItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
        .navigationTitle("搜索")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = .searchFilters
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var results: [PrototypeFeedItem] {
        let scoped = PrototypeFixtures.feedItems.filter { item in
            switch selectedScope {
            case .all:
                return true
            case .enabled:
                return !item.isLocal
            case .local:
                return item.isLocal
            }
        }

        guard !query.isEmpty else { return Array(scoped.prefix(4)) }
        return scoped.filter { item in
            item.title.localizedStandardContains(query)
                || item.source.localizedStandardContains(query)
                || item.tags.contains(where: { $0.localizedStandardContains(query) })
        }
    }
}

private struct SearchHistorySection: View {
    let history: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("搜索历史")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(history, id: \.self) { term in
                    Button {
                        onSelect(term)
                    } label: {
                        HStack {
                            Label(term, systemImage: "clock")
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    if term != history.last {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal)
        }
    }
}

private struct SourceManagementPrototypeView: View {
    @Binding var presentedSheet: PrototypeSheet?
    @State private var enabledSources = PrototypeFixtures.enabledSources
    @State private var disabledSources = PrototypeFixtures.disabledSources
    @State private var localSources = PrototypeFixtures.localSources

    var body: some View {
        List {
            Section("已启用") {
                ForEach(enabledSources) { source in
                    SourceRow(source: source, state: "启用中")
                        .swipeActions(edge: .trailing) {
                            Button {
                                move(source, from: .enabled, to: .disabled)
                            } label: {
                                Label("停用", systemImage: "pause.circle")
                            }

                            Button {
                                presentedSheet = .editSource(source)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button(role: .destructive) {
                                delete(source, from: .enabled)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("编辑", systemImage: "pencil") {
                                presentedSheet = .editSource(source)
                            }
                            Button("测试图源", systemImage: "checkmark.seal") {}
                            Button("复制 URL", systemImage: "doc.on.doc") {}
                        }
                }
                .onMove { indices, newOffset in
                    enabledSources.move(fromOffsets: indices, toOffset: newOffset)
                }
            }

            Section("已停用") {
                ForEach(disabledSources) { source in
                    SourceRow(source: source, state: "已停用")
                        .swipeActions(edge: .trailing) {
                            Button {
                                move(source, from: .disabled, to: .enabled)
                            } label: {
                                Label("启用", systemImage: "play.circle")
                            }

                            Button {
                                presentedSheet = .editSource(source)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button(role: .destructive) {
                                delete(source, from: .disabled)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("启用", systemImage: "play.circle") {
                                move(source, from: .disabled, to: .enabled)
                            }
                            Button("编辑", systemImage: "pencil") {
                                presentedSheet = .editSource(source)
                            }
                        }
                }
                .onMove { indices, newOffset in
                    disabledSources.move(fromOffsets: indices, toOffset: newOffset)
                }
            }

            Section("本地图源") {
                ForEach(localSources) { source in
                    SourceRow(source: source, state: "本地")
                        .swipeActions(edge: .trailing) {
                            Button {
                                presentedSheet = .editSource(source)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                delete(source, from: .local)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("编辑", systemImage: "pencil") {
                                presentedSheet = .editSource(source)
                            }
                            Button("重新扫描", systemImage: "folder.badge.gearshape") {}
                        }
                }
                .onMove { indices, newOffset in
                    localSources.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
        }
        .navigationTitle("图源")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = .addSource
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func move(_ source: PrototypeSource, from sourceList: SourceList, to destinationList: SourceList) {
        delete(source, from: sourceList)
        switch destinationList {
        case .enabled:
            enabledSources.append(source.withEnabledState(true))
        case .disabled:
            disabledSources.append(source.withEnabledState(false))
        case .local:
            localSources.append(source)
        }
    }

    private func delete(_ source: PrototypeSource, from sourceList: SourceList) {
        switch sourceList {
        case .enabled:
            enabledSources.removeAll { $0.id == source.id }
        case .disabled:
            disabledSources.removeAll { $0.id == source.id }
        case .local:
            localSources.removeAll { $0.id == source.id }
        }
    }
}

private enum SourceList {
    case enabled
    case disabled
    case local
}

private struct SourceRow: View {
    let source: PrototypeSource
    let state: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.systemImage)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.body)
                Text(source.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(state)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SourceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: SourceEditorMode

    @State private var name: String
    @State private var url: String
    @State private var type: PrototypeSourceType
    @State private var parseRule = "$.data[*]"
    @State private var headers = "Accept: application/json"
    @State private var cookie = ""
    @State private var userAgent = "Mozilla/5.0"
    @State private var updateFrequency: PrototypeUpdateFrequency = .daily
    @State private var didTest = false

    init(mode: SourceEditorMode) {
        self.mode = mode
        let source = mode.source
        _name = State(initialValue: source?.name ?? "")
        _url = State(initialValue: source?.url ?? "")
        _type = State(initialValue: source?.type ?? .json)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("图源名称", text: $name)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("类型", selection: $type) {
                        ForEach(PrototypeSourceType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section("解析规则") {
                    TextField("列表路径", text: $parseRule)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("封面字段", text: .constant("cover"))
                    TextField("标题字段", text: .constant("title"))
                    TextField("更新时间字段", text: .constant("updated_at"))
                }

                Section("Headers") {
                    TextEditor(text: $headers)
                        .font(.body.monospaced())
                        .frame(minHeight: 88)
                    SecureField("Cookie", text: $cookie)
                    TextField("User-Agent", text: $userAgent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("更新频率") {
                    Picker("频率", selection: $updateFrequency) {
                        ForEach(PrototypeUpdateFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                }

                Section {
                    Button {
                        didTest = true
                    } label: {
                        Label("测试图源", systemImage: "checkmark.seal")
                    }
                }

                if didTest {
                    Section("结果预览") {
                        ForEach(PrototypeFixtures.feedItems.prefix(3)) { item in
                            HStack(spacing: 12) {
                                PrototypeCoverPlaceholder()
                                    .frame(width: 52, height: 68)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                    Text(item.source)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { dismiss() }
                        .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

private enum SourceEditorMode: Hashable {
    case add
    case edit(PrototypeSource)

    var title: String {
        switch self {
        case .add:
            return "添加图源"
        case .edit:
            return "编辑图源"
        }
    }

    var source: PrototypeSource? {
        switch self {
        case .add:
            return nil
        case .edit(let source):
            return source
        }
    }
}

private struct SearchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: PrototypeContentType = .all
    @State private var selectedSort: PrototypeSortMode = .updated
    @State private var includeLocal = true
    @State private var onlyFavorites = false
    @State private var tagMatching: PrototypeTagMatching = .any

    var body: some View {
        NavigationStack {
            Form {
                Section("图源范围") {
                    Toggle("包含本地图源", isOn: $includeLocal)
                    Toggle("仅收藏", isOn: $onlyFavorites)
                }

                Section("内容") {
                    Picker("类型", selection: $selectedType) {
                        ForEach(PrototypeContentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    Picker("标签匹配", selection: $tagMatching) {
                        ForEach(PrototypeTagMatching.allCases) { matching in
                            Text(matching.title).tag(matching)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("排序") {
                    Picker("排序方式", selection: $selectedSort) {
                        ForEach(PrototypeSortMode.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                }
            }
            .navigationTitle("筛选")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("重置") {
                        selectedType = .all
                        selectedSort = .updated
                        includeLocal = true
                        onlyFavorites = false
                        tagMatching = .any
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PrototypeDetailView: View {
    let item: PrototypeFeedItem
    @State private var selectedList: PrototypeDetailList = .images

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PrototypeCoverPlaceholder()
                        .aspectRatio(1.35, contentMode: .fit)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.title2.weight(.semibold))
                        Label(item.source, systemImage: "square.stack.3d.up")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button {} label: {
                            Label("收藏", systemImage: "heart")
                        }
                        .buttonStyle(.glass)

                        Button {} label: {
                            Label("下载", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.glass)

                        NavigationLink(value: PrototypeRoute.reader(item.id)) {
                            Label("浏览", systemImage: "photo")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("标签") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            Section("简介") {
                Text(item.summary)
            }

            Section {
                Picker("列表", selection: $selectedList) {
                    ForEach(PrototypeDetailList.allCases) { list in
                        Text(list.title).tag(list)
                    }
                }
                .pickerStyle(.segmented)
            }

            if selectedList == .images {
                Section("图片") {
                    ForEach(1...8, id: \.self) { index in
                        NavigationLink(value: PrototypeRoute.reader(item.id)) {
                            Label("第 \(index) 张", systemImage: "photo")
                        }
                    }
                }
            } else {
                Section("章节") {
                    ForEach(PrototypeFixtures.chapters, id: \.self) { chapter in
                        NavigationLink(value: PrototypeRoute.reader(item.id)) {
                            Label(chapter, systemImage: "list.bullet.rectangle")
                        }
                    }
                }
            }
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("分享", systemImage: "square.and.arrow.up") {}
                    Button("复制链接", systemImage: "doc.on.doc") {}
                    Button("隐藏来源", systemImage: "eye.slash") {}
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

private struct ImageReaderPrototypeView: View {
    @Environment(\.dismiss) private var dismiss
    let item: PrototypeFeedItem
    @State private var page = 1

    private let pageCount = 8

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            PrototypeCoverPlaceholder()
                .aspectRatio(0.72, contentMode: .fit)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.glass)
            }

            ToolbarItem(placement: .principal) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("分享", systemImage: "square.and.arrow.up") {}
                    Button("保存图片", systemImage: "square.and.arrow.down") {}
                    Button("阅读设置", systemImage: "textformat.size") {}
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.glass)
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    page = max(1, page - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(page == 1)
                .buttonStyle(.glass)

                Spacer()

                Text("\(page) / \(pageCount)")
                    .monospacedDigit()

                Spacer()

                Button {
                    page = min(pageCount, page + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(page == pageCount)
                .buttonStyle(.glass)

                Button {} label: {
                    Image(systemName: "heart")
                }
                .buttonStyle(.glass)
            }
        }
    }
}

private struct SettingsPrototypeView: View {
    @State private var gridDensity: PrototypeGridDensity = .comfortable
    @State private var preloadImages = true
    @State private var cacheLimit = 2
    @State private var autoUpdateSources = true
    @State private var updateOnWiFiOnly = true
    @State private var iCloudBackup = false
    @State private var privacyMode = false

    var body: some View {
        Form {
            Section("浏览") {
                Picker("网格密度", selection: $gridDensity) {
                    ForEach(PrototypeGridDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                Toggle("预载下一页图片", isOn: $preloadImages)
                Toggle("显示来源和更新时间", isOn: .constant(true))
            }

            Section("缓存") {
                Stepper("缓存上限 \(cacheLimit) GB", value: $cacheLimit, in: 1...20)
                Button("清理图片缓存", systemImage: "trash") {}
            }

            Section("图源更新") {
                Toggle("自动更新图源", isOn: $autoUpdateSources)
                Toggle("仅 Wi-Fi 更新", isOn: $updateOnWiFiOnly)
                Button("立即检查更新", systemImage: "arrow.clockwise") {}
            }

            Section("备份") {
                Toggle("iCloud 备份图源配置", isOn: $iCloudBackup)
                Button("导出配置", systemImage: "square.and.arrow.up") {}
                Button("导入配置", systemImage: "square.and.arrow.down") {}
            }

            Section("隐私") {
                Toggle("隐私浏览模式", isOn: $privacyMode)
                Button("清除搜索历史", systemImage: "clock.badge.xmark") {}
            }

            Section("关于") {
                LabeledContent("版本", value: "0.1 Layout")
                NavigationLink("开源许可") {
                    List {
                        Text("SwiftUI")
                        Text("Apple system frameworks")
                    }
                    .navigationTitle("开源许可")
                }
            }
        }
        .navigationTitle("设置")
    }
}

private struct PrototypeItemCard: View {
    let item: PrototypeFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PrototypeCoverPlaceholder()
                .aspectRatio(0.78, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(item.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.updatedAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PrototypeCoverPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum PrototypeSourceScope: String, CaseIterable, Identifiable {
    case all
    case enabled
    case local

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .enabled:
            return "启用"
        case .local:
            return "本地"
        }
    }
}

private enum PrototypeSearchScope: String, CaseIterable, Identifiable {
    case all
    case enabled
    case local

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .enabled:
            return "在线"
        case .local:
            return "本地"
        }
    }
}

private enum PrototypeSourceType: String, CaseIterable, Identifiable, Hashable {
    case json
    case html
    case rss
    case local

    var id: Self { self }

    var title: String {
        switch self {
        case .json:
            return "JSON"
        case .html:
            return "HTML"
        case .rss:
            return "RSS"
        case .local:
            return "本地"
        }
    }

    var systemImage: String {
        switch self {
        case .json:
            return "curlybraces"
        case .html:
            return "doc.text"
        case .rss:
            return "dot.radiowaves.left.and.right"
        case .local:
            return "folder"
        }
    }
}

private enum PrototypeUpdateFrequency: String, CaseIterable, Identifiable {
    case manual
    case hourly
    case daily
    case weekly

    var id: Self { self }

    var title: String {
        switch self {
        case .manual:
            return "手动"
        case .hourly:
            return "每小时"
        case .daily:
            return "每天"
        case .weekly:
            return "每周"
        }
    }
}

private enum PrototypeContentType: String, CaseIterable, Identifiable {
    case all
    case image
    case album
    case chapter

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .image:
            return "图片"
        case .album:
            return "合集"
        case .chapter:
            return "章节"
        }
    }
}

private enum PrototypeSortMode: String, CaseIterable, Identifiable {
    case updated
    case relevance
    case source

    var id: Self { self }

    var title: String {
        switch self {
        case .updated:
            return "更新时间"
        case .relevance:
            return "相关度"
        case .source:
            return "图源"
        }
    }
}

private enum PrototypeTagMatching: String, CaseIterable, Identifiable {
    case any
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .any:
            return "任意"
        case .all:
            return "全部"
        }
    }
}

private enum PrototypeDetailList: String, CaseIterable, Identifiable {
    case images
    case chapters

    var id: Self { self }

    var title: String {
        switch self {
        case .images:
            return "图片"
        case .chapters:
            return "章节"
        }
    }
}

private enum PrototypeGridDensity: String, CaseIterable, Identifiable {
    case compact
    case comfortable
    case large

    var id: Self { self }

    var title: String {
        switch self {
        case .compact:
            return "紧凑"
        case .comfortable:
            return "标准"
        case .large:
            return "宽松"
        }
    }
}

private struct PrototypeFeedItem: Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
    let updatedAt: String
    let tags: [String]
    let summary: String
    let isLocal: Bool
}

private struct PrototypeSource: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let type: PrototypeSourceType
    let isEnabled: Bool

    var systemImage: String { type.systemImage }

    func withEnabledState(_ isEnabled: Bool) -> PrototypeSource {
        PrototypeSource(id: id, name: name, url: url, type: type, isEnabled: isEnabled)
    }
}

private enum PrototypeFixtures {
    static let feedItems: [PrototypeFeedItem] = [
        PrototypeFeedItem(
            id: "city",
            title: "城市夜景合集",
            source: "Wallhaven",
            updatedAt: "10 分钟前",
            tags: ["城市", "夜景", "4K"],
            summary: "来自多个在线图源的城市夜景聚合条目，详情页用于展示标题、来源、标签、简介和图片列表的布局。",
            isLocal: false
        ),
        PrototypeFeedItem(
            id: "forest",
            title: "森林与溪流",
            source: "Bing Wallpaper",
            updatedAt: "1 小时前",
            tags: ["自然", "横图", "风景"],
            summary: "用于验证封面、元信息、操作按钮以及图片 / 章节列表在详情页中的层级关系。",
            isLocal: false
        ),
        PrototypeFeedItem(
            id: "cover",
            title: "章节封面采样",
            source: "本地文件夹",
            updatedAt: "今天",
            tags: ["本地", "封面", "章节"],
            summary: "本地图源条目，用来检查管理页、本地图源筛选和全屏浏览工具栏的交互入口。",
            isLocal: true
        ),
        PrototypeFeedItem(
            id: "archive",
            title: "设计资料归档",
            source: "自定义 JSON",
            updatedAt: "昨天",
            tags: ["资料", "合集", "JSON"],
            summary: "一个自定义 JSON 图源示例，呈现自由添加图源后进入聚合首页、搜索结果和详情页的路径。",
            isLocal: false
        ),
        PrototypeFeedItem(
            id: "manga",
            title: "连载章节更新",
            source: "HTML Parser",
            updatedAt: "2 天前",
            tags: ["章节", "连载", "HTML"],
            summary: "用于展示章节列表模式的布局原型，章节行通过 Navigation Push 进入全屏图片浏览。",
            isLocal: false
        ),
        PrototypeFeedItem(
            id: "favorites",
            title: "收藏夹导入",
            source: "本地文件夹",
            updatedAt: "上周",
            tags: ["收藏", "本地", "备份"],
            summary: "本地收藏导入条目，帮助确认设置里的备份、缓存和隐私项目是否覆盖主要管理场景。",
            isLocal: true
        )
    ]

    static let enabledSources: [PrototypeSource] = [
        PrototypeSource(id: "wallhaven", name: "Wallhaven", url: "https://wallhaven.cc/api/v1/search", type: .json, isEnabled: true),
        PrototypeSource(id: "bing", name: "Bing Wallpaper", url: "https://www.bing.com/HPImageArchive.aspx", type: .json, isEnabled: true),
        PrototypeSource(id: "html", name: "HTML Parser", url: "https://example.com/gallery", type: .html, isEnabled: true)
    ]

    static let disabledSources: [PrototypeSource] = [
        PrototypeSource(id: "rss", name: "RSS Archive", url: "https://example.com/feed.xml", type: .rss, isEnabled: false)
    ]

    static let localSources: [PrototypeSource] = [
        PrototypeSource(id: "local-covers", name: "本地封面", url: "On My iPhone/Covers", type: .local, isEnabled: true),
        PrototypeSource(id: "local-favorites", name: "收藏夹导入", url: "On My iPhone/Favorites", type: .local, isEnabled: true)
    ]

    static let chapters = ["第 1 章", "第 2 章", "第 3 章", "番外"]

    static func item(id: String) -> PrototypeFeedItem {
        feedItems.first { $0.id == id } ?? feedItems[0]
    }
}

#Preview {
    ImageSourcePrototypeView()
}
