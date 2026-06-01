import SwiftUI

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BrowseViewModel
    let showsDoneButton: Bool

    @State private var apiKey: String

    init(viewModel: BrowseViewModel, showsDoneButton: Bool = true) {
        self.viewModel = viewModel
        self.showsDoneButton = showsDoneButton
        let key = viewModel.activeSourceEngine.trimmedAPIKey.isEmpty
            ? viewModel.sourceConfiguration.apiKey
            : viewModel.activeSourceEngine.apiKey
        _apiKey = State(initialValue: key)
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.activeSourceEngine.supportsWallhavenFilters {
                    Section("排序") {
                        Picker("排序方式", selection: Binding(
                            get: { viewModel.currentSorting },
                            set: { sorting in Task { await viewModel.onSortSelected(sorting) } }
                        )) {
                            ForEach(viewModel.sortingOptions, id: \.self) { sorting in
                                Text(sorting.displayName).tag(sorting)
                            }
                        }

                        Picker("顺序", selection: Binding(
                            get: { viewModel.sourceConfiguration.order },
                            set: { order in Task { await viewModel.onOrderSelected(order) } }
                        )) {
                            ForEach(viewModel.orderOptions) { order in
                                Text(order.displayName).tag(order)
                            }
                        }

                        if viewModel.currentSorting == .toplist {
                            Picker("榜单范围", selection: Binding(
                                get: { viewModel.sourceConfiguration.topRange },
                                set: { range in Task { await viewModel.onTopRangeSelected(range) } }
                            )) {
                                ForEach(viewModel.topRangeOptions) { range in
                                    Text(range.displayName).tag(range)
                                }
                            }
                        }
                    }

                    Section("分类") {
                        ForEach(viewModel.categoryOptions) { category in
                            Toggle(isOn: Binding(
                                get: { viewModel.sourceConfiguration.categories.contains(category) },
                                set: { _ in Task { await viewModel.onCategoryToggled(category) } }
                            )) {
                                Label(category.displayName, systemImage: category.systemImage)
                            }
                        }
                    }

                    Section("分级") {
                        ForEach(viewModel.purityOptions) { purity in
                            Toggle(isOn: Binding(
                                get: { viewModel.sourceConfiguration.purities.contains(purity) },
                                set: { _ in Task { await viewModel.onPurityToggled(purity) } }
                            )) {
                                Label(purity.displayName, systemImage: purity.systemImage)
                            }
                            .disabled(purity == .nsfw && !viewModel.sourceConfiguration.hasAPIKey && !viewModel.activeSourceEngine.hasAPIKey)
                        }
                    }

                    Section("Wallhaven API Key") {
                        SecureField("API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("保存密钥") {
                            Task { await viewModel.onAPIKeyChanged(apiKey) }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "当前图源没有筛选项",
                            systemImage: "slider.horizontal.3",
                            description: Text("通用 JSON 图源使用导入配置里的参数。")
                        )
                    }
                }
            }
            .navigationTitle("筛选")
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
}
