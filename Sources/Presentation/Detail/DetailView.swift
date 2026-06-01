import Photos
import SwiftUI

struct DetailView: View {
    let wallpaper: Wallpaper
    let imageLoader: ImageLoader

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var isLoading = true
    @State private var didFailLoading = false
    @State private var saveMessage: SaveMessage?

    var body: some View {
        NavigationStack {
            Group {
                if let image = fullImage {
                    ZoomableScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                } else if isLoading {
                    ProgressView()
                } else if didFailLoading {
                    ContentUnavailableView {
                        Label("图片加载失败", systemImage: "photo.badge.exclamationmark")
                    } description: {
                        Text("请检查网络后重试")
                    } actions: {
                        Button("重试") {
                            Task { await loadFullImage() }
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle(wallpaper.title ?? wallpaper.categoryDisplay)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        ShareLink(item: wallpaper.fullImageURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.glass)

                        Button {
                            Task { await saveToPhotos() }
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .task(id: wallpaper.fullImageURL) {
                await loadFullImage()
            }
            .alert(item: $saveMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private func saveToPhotos() async {
        guard let image = fullImage else {
            saveMessage = SaveMessage(title: "无法保存", message: "图片还没有加载完成。")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            saveMessage = SaveMessage(title: "已保存", message: "图片已保存到照片。")
        } catch {
            saveMessage = SaveMessage(title: "保存失败", message: error.localizedDescription)
        }
    }

    private func loadFullImage() async {
        isLoading = true
        didFailLoading = false
        fullImage = await imageLoader.loadImage(from: wallpaper.fullImageURL)
        didFailLoading = fullImage == nil
        isLoading = false
    }
}

private struct SaveMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5
        scrollView.minimumZoomScale = 1
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true

        let host = UIHostingController(rootView: content())
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        scrollView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            host.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        context.coordinator.hostingController = host
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }
    }
}
