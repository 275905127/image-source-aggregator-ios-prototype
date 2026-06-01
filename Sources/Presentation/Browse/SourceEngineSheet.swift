import SwiftUI

struct SourceEngineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BrowseViewModel
    let showsDoneButton: Bool

    @State private var isImportPresented = false

    init(viewModel: BrowseViewModel, showsDoneButton: Bool = true) {
        self.viewModel = viewModel
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isImportPresented = true
                    } label: {
                        Label("导入图源配置", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("粘贴通用 JSON 图源配置，支持单个图源或图源数组。")
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
                    }
                }
            }
            .navigationTitle("图源")
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $isImportPresented) {
                SourceConfigurationImportSheet { sources in
                    Task { await viewModel.onSourcesImported(sources) }
                }
            }
            .presentationDetents([.large])
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
                Text(source.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        switch source.kind {
        case .wallhaven:
            return source.request.normalizedBaseURL
        case .jsonAPI:
            return source.request.normalizedBaseURL.isEmpty ? "未配置 API 地址" : source.request.normalizedBaseURL
        case .directLinks:
            return "\(source.directImages.count) 张图片"
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
