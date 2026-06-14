import SwiftUI

struct SourceEngineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: BrowseViewModel
    let showsDoneButton: Bool

    @State private var presentedSheet: SourceEngineSheetDestination?

    init(viewModel: BrowseViewModel, showsDoneButton: Bool = true) {
        self.viewModel = viewModel
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        presentedSheet = .templates
                    } label: {
                        Label("添加图源", systemImage: "plus.circle")
                    }

                    Button {
                        presentedSheet = .importConfiguration
                    } label: {
                        Label("导入 JSON 配置", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("可以从内置模板开始，也可以粘贴通用 JSON 图源配置。")
                }

                Section("当前图源") {
                    ForEach(viewModel.sourceEngines) { source in
                        SourceEngineRow(
                            source: source,
                            isSelected: source.id == viewModel.activeSourceEngine.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await viewModel.onSourceSelected(source) }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.onSourceDeleted(source) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .disabled(viewModel.sourceEngines.count == 1)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                presentedSheet = .test(source)
                            } label: {
                                Label("测试", systemImage: "stethoscope")
                            }
                            .tint(.blue)

                            Button {
                                presentedSheet = .edit(source)
                            } label: {
                                Label("编辑", systemImage: "slider.horizontal.3")
                            }
                            .tint(.indigo)
                        }
                    }
                }
            }
            .navigationTitle("图源")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = .templates
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .sheet(item: $presentedSheet) { destination in
                switch destination {
                case .templates:
                    SourceTemplateLibrarySheet(templates: viewModel.sourceTemplates) { template in
                        Task { await viewModel.onSourceTemplateAdded(template) }
                    }
                case .importConfiguration:
                    SourceConfigurationImportSheet { sources in
                        Task { await viewModel.onSourcesImported(sources) }
                    }
                case .edit(let source):
                    SourceEngineEditorSheet(source: source) { updatedSource in
                        Task { await viewModel.onSourceSaved(updatedSource) }
                    }
                case .test(let source):
                    SourceEngineTestSheet(source: source, viewModel: viewModel)
                }
            }
            .presentationDetents([.large])
        }
    }
}

private enum SourceEngineSheetDestination: Identifiable {
    case templates
    case importConfiguration
    case edit(WallpaperSourceEngine)
    case test(WallpaperSourceEngine)

    var id: String {
        switch self {
        case .templates:
            return "templates"
        case .importConfiguration:
            return "import"
        case .edit(let source):
            return "edit-\(source.id.uuidString)"
        case .test(let source):
            return "test-\(source.id.uuidString)"
        }
    }
}

private struct SourceEngineRow: View {
    let source: WallpaperSourceEngine
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.body.weight(.medium))
                    if source.isBuiltInTemplate {
                        Image(systemName: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if source.hasAPIKey {
                        Label("密钥", systemImage: "key.fill")
                    }
                    if supportsSearch {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                    if source.kind != .directLinks {
                        Label(pageText, systemImage: "arrow.down.forward.and.arrow.up.backward")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    private var supportsSearch: Bool {
        !source.request.searchQueryName.isEmpty
    }

    private var pageText: String {
        source.request.pageQueryName.isEmpty ? "单页" : "分页"
    }

    private var subtitle: String {
        switch source.kind {
        case .wallhaven:
            return source.request.normalizedBaseURL
        case .jsonAPI:
            return source.request.normalizedBaseURL.isEmpty ? "未配置 API 地址" : source.request.normalizedBaseURL + source.request.pathTemplate
        case .directLinks:
            return "\(source.validDirectImageURLs.count) / \(source.directImages.count) 张有效图片"
        }
    }
}

private struct SourceTemplateLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WallpaperSourceEngine]
    let onAdd: (WallpaperSourceEngine) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("内置模板") {
                    ForEach(templates) { template in
                        Button {
                            onAdd(template)
                            dismiss()
                        } label: {
                            SourceTemplateRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("添加图源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SourceTemplateRow: View {
    let template: WallpaperSourceEngine

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.kind.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }

    private var description: String {
        switch template.kind {
        case .wallhaven:
            return "完整 Wallhaven 搜索、排序、分级模板"
        case .jsonAPI:
            return template.request.normalizedBaseURL + template.request.pathTemplate
        case .directLinks:
            return "从一组图片 URL 快速创建图源"
        }
    }
}

private struct SourceEngineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WallpaperSourceEngine
    @State private var staticQueryText: String
    @State private var staticHeaderText: String
    @State private var directLinksText: String

    let onSave: (WallpaperSourceEngine) -> Void

    init(source: WallpaperSourceEngine, onSave: @escaping (WallpaperSourceEngine) -> Void) {
        _draft = State(initialValue: source)
        _staticQueryText = State(initialValue: source.request.staticQueryItems.keyValueLines)
        _staticHeaderText = State(initialValue: source.request.staticHeaders.keyValueLines)
        _directLinksText = State(initialValue: source.directImages.joined(separator: "\n"))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("名称", text: $draft.name)
                    Picker("类型", selection: $draft.kind) {
                        ForEach(WallpaperSourceEngineKind.allCases) { kind in
                            Label(kind.displayName, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                }

                if draft.kind == .directLinks {
                    directLinksSection
                } else {
                    requestSection
                    mappingSection
                    securitySection
                }
            }
            .navigationTitle("编辑图源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var source = draft
                        source.request.staticQueryItems = SourceEngineQueryItem.lines(from: staticQueryText)
                        source.request.staticHeaders = SourceEngineHeader.lines(from: staticHeaderText)
                        source.directImages = directLinksText.lines
                        onSave(source)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var directLinksSection: some View {
        Section {
            TextEditor(text: $directLinksText)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 220)
        } header: {
            Text("图片直链")
        } footer: {
            Text("每行一个 http/https 图片地址。")
        }
    }

    private var requestSection: some View {
        Section("请求") {
            TextField("Base URL", text: $draft.request.baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Path", text: $draft.request.pathTemplate)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Picker("Method", selection: $draft.request.method) {
                Text("GET").tag("GET")
                Text("POST").tag("POST")
            }
            TextField("分页参数", text: $draft.request.pageQueryName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("搜索参数", text: $draft.request.searchQueryName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            KeyValueTextEditor(title: "固定查询参数", text: $staticQueryText)
        }
    }

    private var mappingSection: some View {
        Section {
            TextField("Items Path", text: $draft.mapping.itemsPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("ID Path", text: $draft.mapping.idPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("缩略图 Path", text: $draft.mapping.thumbnailURLPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("原图 Path", text: $draft.mapping.fullImageURLPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("缩略图 URL 前缀", text: Binding($draft.mapping.thumbnailURLPrefix, replacingNilWith: ""))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("原图 URL 前缀", text: Binding($draft.mapping.fullImageURLPrefix, replacingNilWith: ""))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("标题 Path", text: $draft.mapping.titlePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("作者 Path", text: $draft.mapping.authorPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("宽度 Path", text: $draft.mapping.widthPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("高度 Path", text: $draft.mapping.heightPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Has More Path", text: $draft.mapping.hasMorePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Last Page Path", text: $draft.mapping.lastPagePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Toggle("默认还有下一页", isOn: Binding(
                get: { draft.mapping.defaultHasMore ?? false },
                set: { draft.mapping.defaultHasMore = $0 }
            ))
        } header: {
            Text("JSON 映射")
        } footer: {
            Text("Path 支持 data.items、images.0.url、$.data[*].url 这类常见写法。")
        }
    }

    private var securitySection: some View {
        Section {
            Picker("密钥位置", selection: $draft.request.apiKeyPlacement) {
                Text("Query").tag(SourceEngineAPIKeyPlacement.query)
                Text("Header").tag(SourceEngineAPIKeyPlacement.header)
                Text("Bearer").tag(SourceEngineAPIKeyPlacement.bearer)
            }
            TextField("密钥参数/头名称", text: $draft.request.apiKeyQueryName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("API Key", text: $draft.apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            KeyValueTextEditor(title: "固定请求头", text: $staticHeaderText)
        } header: {
            Text("密钥与请求头")
        } footer: {
            Text("密钥会写入 Keychain；导出的图源 JSON 不会包含明文密钥。")
        }
    }
}

private struct KeyValueTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 88)
        }
    }
}

private struct SourceEngineTestSheet: View {
    @Environment(\.dismiss) private var dismiss

    let source: WallpaperSourceEngine
    let viewModel: BrowseViewModel

    @State private var report: WallpaperSourceTestReport?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            List {
                Section("端点") {
                    Text(report?.endpointDescription ?? "准备测试 \(source.name)")
                        .font(.caption)
                        .textSelection(.enabled)
                }

                if isTesting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("正在请求并解析第一页")
                        }
                    }
                }

                if let report {
                    Section("结果") {
                        Label(report.summary, systemImage: report.isUsable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(report.isUsable ? .green : .orange)
                        if let hasMore = report.hasMore {
                            Label(hasMore ? "还有下一页" : "没有下一页", systemImage: hasMore ? "arrow.down.forward" : "stop.circle")
                        }
                    }

                    if !report.issues.isEmpty {
                        Section("诊断") {
                            ForEach(report.issues) { issue in
                                SourceIssueRow(issue: issue)
                            }
                        }
                    }

                    if !report.sampleWallpapers.isEmpty {
                        Section("样例") {
                            ForEach(report.sampleWallpapers) { wallpaper in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(wallpaper.title ?? wallpaper.fullImageURL.lastPathComponent)
                                        .font(.body.weight(.medium))
                                        .lineLimit(2)
                                    Text(wallpaper.fullImageURL.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(wallpaper.resolution)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("测试图源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("重测") {
                        Task { await runTest() }
                    }
                    .disabled(isTesting)
                }
            }
            .task {
                await runTest()
            }
        }
        .presentationDetents([.large])
    }

    private func runTest() async {
        guard !isTesting else { return }
        isTesting = true
        report = await viewModel.onSourceTestRequested(source)
        isTesting = false
    }
}

private struct SourceIssueRow: View {
    let issue: WallpaperSourceValidationIssue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(.body.weight(.medium))
                Text(issue.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch issue.severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var color: Color {
        switch issue.severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

private struct SourceConfigurationImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var configurationText = defaultConfigurationText
    @State private var errorMessage: String?
    @State private var previews: [WallpaperSourcePreview] = []

    let onImport: ([WallpaperSourceEngine]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $configurationText)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: 360)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .onChange(of: configurationText) { _, _ in
                            updatePreview()
                        }
                } header: {
                    Text("JSON 配置")
                } footer: {
                    Text("支持单个对象或数组。导入同名图源会覆盖原配置。")
                }

                if !previews.isEmpty {
                    Section("预览") {
                        ForEach(previews) { preview in
                            SourcePreviewRow(preview: preview)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                    }
                }
            }
            .navigationTitle("导入图源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        do {
                            let sources = try WallpaperSourceImporter.importSources(from: configurationText)
                            onImport(sources)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(configurationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .task {
            updatePreview()
        }
    }

    private func updatePreview() {
        do {
            previews = try WallpaperSourceImporter.previewSources(from: configurationText)
        } catch {
            previews = []
        }
    }

    private static let defaultConfigurationText = """
    [
      {
        "name": "Wallhaven",
        "type": "json",
        "enabled": true,
        "request": {
          "url": "https://wallhaven.cc/api/v1/search",
          "method": "GET",
          "params": {
            "categories": "111",
            "purity": "100",
            "sorting": "toplist",
            "order": "desc",
            "topRange": "1M"
          },
          "auth": {
            "type": "query",
            "key": "apikey",
            "value": "YOUR_API_KEY"
          }
        },
        "pagination": {
          "type": "page",
          "param": "page",
          "start": 1,
          "next": "increment",
          "hasMorePath": "meta.last_page"
        },
        "search": {
          "enabled": true,
          "param": "q"
        }
      },
      {
        "name": "Bing Wallpaper",
        "type": "json",
        "enabled": true,
        "request": {
          "url": "https://www.bing.com/HPImageArchive.aspx",
          "method": "GET",
          "params": {
            "format": "js",
            "idx": "0",
            "n": "8"
          }
        },
        "pagination": {
          "type": "none"
        },
        "search": {
          "enabled": false
        }
      }
    ]
    """
}

private struct SourcePreviewRow: View {
    let preview: WallpaperSourcePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(preview.name)
                Spacer()
                if preview.usesAPIKey {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                }
                if preview.supportsSearch {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
            Text(preview.endpoint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(preview.type)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                source.wrappedValue = trimmed.isEmpty ? nil : newValue
            }
        )
    }
}

private extension String {
    var lines: [String] {
        split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension Array where Element == SourceEngineQueryItem {
    var keyValueLines: String {
        map { "\($0.name): \($0.value)" }.joined(separator: "\n")
    }
}

private extension Array where Element == SourceEngineHeader {
    var keyValueLines: String {
        map { "\($0.name): \($0.value)" }.joined(separator: "\n")
    }
}

private extension SourceEngineQueryItem {
    static func lines(from text: String) -> [SourceEngineQueryItem] {
        text.keyValuePairs.map { SourceEngineQueryItem(name: $0.key, value: $0.value) }
    }
}

private extension SourceEngineHeader {
    static func lines(from text: String) -> [SourceEngineHeader] {
        text.keyValuePairs.map { SourceEngineHeader(name: $0.key, value: $0.value) }
    }
}

private extension String {
    var keyValuePairs: [(key: String, value: String)] {
        lines.compactMap { line in
            let separators = [":", "="]
            guard let separatorIndex = separators.compactMap({ line.firstIndex(of: Character($0)) }).min() else {
                return nil
            }
            let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStart = line.index(after: separatorIndex)
            let value = String(line[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return nil }
            return (key, value)
        }
    }
}
