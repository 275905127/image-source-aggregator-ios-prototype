import SwiftUI

struct MasonryWallpaperGrid: View {
    let wallpapers: [Wallpaper]
    let viewModel: BrowseViewModel
    let onSelect: (Wallpaper) -> Void

    private let spacing: CGFloat = 10
    private let horizontalInset: CGFloat = 10
    private let bottomInset: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let layout = MasonryLayout(
                wallpapers: wallpapers,
                containerWidth: proxy.size.width,
                spacing: spacing,
                horizontalInset: horizontalInset
            )

            ScrollView {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(layout.columns.indices, id: \.self) { columnIndex in
                        LazyVStack(spacing: spacing) {
                            ForEach(layout.columns[columnIndex]) { item in
                                WallpaperCard(
                                    wallpaper: item.wallpaper,
                                    viewModel: viewModel,
                                    width: layout.columnWidth,
                                    height: item.height
                                )
                                .onTapGesture { onSelect(item.wallpaper) }
                            }
                        }
                        .frame(width: layout.columnWidth, alignment: .top)
                    }
                }
                .padding(.horizontal, horizontalInset)
                .padding(.top, 10)
                .padding(.bottom, bottomInset)
                .frame(width: proxy.size.width, alignment: .top)
            }
            .refreshable { await viewModel.onRefresh() }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                guard !wallpapers.isEmpty else { return false }
                let visibleMaxY = geometry.contentOffset.y + geometry.containerSize.height
                let triggerY = max(0, geometry.contentSize.height - 900)
                return visibleMaxY >= triggerY
            } action: { _, isNearBottom in
                guard isNearBottom else { return }
                Task { @MainActor in
                    viewModel.onItemAppear(index: wallpapers.count - 1)
                }
            }
        }
    }
}

private struct MasonryLayout {
    let columns: [[MasonryItem]]
    let columnWidth: CGFloat
    let columnCount: Int

    init(wallpapers: [Wallpaper], containerWidth: CGFloat, spacing: CGFloat, horizontalInset: CGFloat) {
        let columnCount = Self.columnCount(for: containerWidth)
        let contentWidth = max(0, containerWidth - horizontalInset * 2)
        let rawColumnWidth = (contentWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        let safeColumnWidth = floor(max(120, rawColumnWidth))

        var columns = Array(repeating: [MasonryItem](), count: columnCount)
        var columnHeights = [CGFloat](repeating: 0, count: columnCount)

        for (index, wallpaper) in wallpapers.enumerated() {
            let targetColumn = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let height = Self.estimatedHeight(for: wallpaper, columnWidth: safeColumnWidth)
            columns[targetColumn].append(MasonryItem(index: index, wallpaper: wallpaper, height: height))
            columnHeights[targetColumn] += height + spacing
        }

        self.columns = columns
        self.columnWidth = safeColumnWidth
        self.columnCount = columnCount
    }
}

private struct MasonryItem: Identifiable {
    let index: Int
    let wallpaper: Wallpaper
    let height: CGFloat

    var id: String { wallpaper.id }
}

private extension MasonryLayout {
    static func columnCount(for width: CGFloat) -> Int {
        if width >= 900 { return 4 }
        if width >= 680 { return 3 }
        return 2
    }

    static func estimatedHeight(for wallpaper: Wallpaper, columnWidth: CGFloat) -> CGFloat {
        guard let size = wallpaper.pixelSize, size.width > 0, size.height > 0 else {
            return columnWidth * 1.32
        }

        let ratio = size.height / size.width
        return min(max(columnWidth * ratio, columnWidth * 0.72), columnWidth * 2.15)
    }
}
