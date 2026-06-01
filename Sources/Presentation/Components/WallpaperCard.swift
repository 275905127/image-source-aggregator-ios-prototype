import SwiftUI

struct WallpaperCard: View {
    @Environment(\.displayScale) private var displayScale

    let wallpaper: Wallpaper
    let viewModel: BrowseViewModel
    let width: CGFloat
    let height: CGFloat

    @State private var image: UIImage?

    var body: some View {
        imageSection
            .frame(width: width, height: height)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var imageSection: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .task(id: wallpaper.thumbnailURL) {
            image = nil
            let targetSize = CGSize(width: width * displayScale, height: height * displayScale)
            image = await viewModel.loadThumbnail(from: wallpaper.thumbnailURL, targetPixelSize: targetSize)
        }
    }
}
