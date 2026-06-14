# Image Source Aggregator iOS

SwiftUI iPhone app for aggregating wallpaper/image sources. The app now starts in the real browsing experience instead of the static prototype, with source engines, import, editing, diagnostics, paging, caching, and detail viewing wired through the domain/data layers.

## Platform

- Swift 6
- iOS 26 deployment target, with iOS 27-ready Liquid Glass usage kept native where available
- XcodeGen project definition in `project.yml`
- Native SwiftUI Liquid Glass controls for modern iOS UI

## Current Features

- Browse wallpapers from the active source in a masonry grid.
- Search sources that expose a query parameter.
- Switch between multiple source engines.
- Add built-in source templates:
  - Wallhaven
  - Bing Wallpaper
  - Lorem Picsum
  - Blank JSON API
  - Blank direct image links
- Import source definitions from JSON.
- Edit source request, mapping, headers, API key placement, and direct links.
- Test a source from the app and inspect endpoint, validation issues, parsed samples, and pagination status.
- Store API keys in Keychain instead of encoded source JSON.
- Cache images in memory and on disk, with thumbnail downsampling.

## Architecture

- `Sources/App`: app entry point.
- `Sources/Presentation`: SwiftUI screens, sheets, grid, cards, and detail view.
- `Sources/Domain/Engine`: source engine model, templates, import, validation, feed orchestration, pagination, prefetch, and deduplication.
- `Sources/Data`: Wallhaven API, generic JSON/direct-link repository, DTO mapping, and source filter persistence.
- `Sources/Core`: network, image cache, keychain, and scheduling helpers.
- `Tests`: source import, mapping, template, and diagnostics tests.

## Source Engine JSON

A JSON API source can be a single object or an array:

```json
{
  "name": "Example API",
  "type": "json",
  "request": {
    "url": "https://example.com/images",
    "method": "GET",
    "params": {
      "limit": "60"
    },
    "auth": {
      "type": "bearer",
      "key": "Authorization",
      "value": "YOUR_API_KEY"
    }
  },
  "pagination": {
    "type": "page",
    "param": "page",
    "hasMorePath": "meta.has_more"
  },
  "search": {
    "enabled": true,
    "param": "q"
  },
  "mapping": {
    "items": "$.data[*]",
    "id": "id",
    "thumbnail": "assets[0].url",
    "image": "assets[1].url",
    "title": "title",
    "author": "user.name",
    "width": "width",
    "height": "height"
  }
}
```

`mapping` paths support simple dot paths and common JSONPath-style forms such as `$.data[*]` and `assets[0].url`.

Direct-link sources are also supported:

```json
{
  "name": "My Direct Images",
  "type": "direct",
  "urls": [
    "https://example.com/a.jpg",
    "https://example.com/b.jpg"
  ]
}
```

## Build

Generate the Xcode project with XcodeGen, then build the `Wallhaven` scheme on iOS 26:

```bash
xcodegen generate
xcodebuild -project Wallhaven.xcodeproj -scheme Wallhaven -destination 'generic/platform=iOS Simulator' build
```

On Windows, Swift package tests can parse the code but iOS frameworks such as SwiftUI/UIKit/Security are not available, so full build verification must run on macOS with Xcode.
