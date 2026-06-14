import SwiftUI

@main
struct WallhavenApp: App {
    var body: some Scene {
        WindowGroup {
            BrowseView(
                viewModel: BrowseViewModel(
                    feedEngine: FeedEngine(),
                    imageLoader: ImageLoader()
                )
            )
        }
    }
}
