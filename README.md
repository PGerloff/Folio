# Bedside · iOS (Swift / SwiftUI)

A quiet, beautiful reading-list app for iOS. Previously named **Folio** — see `CLAUDE.md` for the rename context.

## What's here

- **SwiftUI** views (iOS 17+) — uses the new `@Observable` macro and `PhotosPicker`.
- **No external dependencies.** Just Foundation + SwiftUI + PhotosUI + UIKit (the last only for `UIImagePickerController` camera capture).
- **File-based persistence.** Books + favorite authors are stored as JSON at `Documents/bedside.json`. Cover photos live as JPEGs at `Documents/covers/<UUID>.jpg`. A legacy `folio.json` file is migrated once on first launch.
- **XcodeGen** for the Xcode project — `project.yml` is the source of truth.

## Setup (Xcode 16+)

```
brew install xcodegen
git clone https://github.com/PGerloff/Folio.git
cd Folio
xcodegen generate
open Bedside.xcodeproj
```

Then ⌘R to build and run. Camera capture only works on a real device; the simulator falls back to "Choose from Library."

## Architecture

```
.
├── BedsideApp.swift              @main — wires up BookStore in the environment
├── Info.plist                    camera + photo library usage strings
├── PrivacyInfo.xcprivacy         App Store privacy manifest (no tracking, no data collection)
├── project.yml                   XcodeGen spec
├── Models/Models.swift           Book, BookStatus, CoverColor, Note
├── Store/
│   ├── BookStore.swift           @Observable persistence layer + NSCache
│   └── OpenLibrary.swift         User-Agent + timeout helper for OL API
├── Theme/Theme.swift             Bedside palette, fonts, shared modifiers
├── Components/
│   ├── CoverView.swift           photo-or-tile cover renderer with cross-fade
│   ├── StarsView.swift           1–5 stars, read-only or tappable
│   ├── StatusPicker.swift        Shop / To Read / Reading / Paused / Finished
│   ├── PhotoPickerButton.swift   combined camera + library picker
│   ├── ShareSheet.swift          UIActivityViewController wrapper
│   └── BookShareContent.swift    share-text composer + cover image renderer
├── Views/
│   ├── RootView.swift            TabView shell, sheet routing
│   ├── HomeView.swift            shopping-first landing screen
│   ├── ShopView.swift            buy list with one-tap "mark as bought"
│   ├── LibraryView.swift         3-column grid, filter chips
│   ├── BookDetailView.swift      cover hero, status, rating, notes
│   ├── AddBookSheet.swift        quick-add bottom sheet
│   ├── ManualEntryView.swift     full form with photo capture
│   └── YouView.swift             stats, favourite authors, settings
└── BedsideTests/                 Swift Testing — 32 tests across 4 suites
```

## Persistence layout

| Concept                | Implementation |
| ---                    | --- |
| Library JSON           | `JSONEncoder` → `Documents/bedside.json` |
| Legacy migration       | `folio.json` → `bedside.json` on first launch |
| Photo data             | JPEGs written to `Documents/covers/` via `UIImage.jpegData(0.85)` |
| Decoded image cache    | `NSCache<NSString, UIImage>` (200-item limit) |
| Corrupted store backup | `Documents/bedside.corrupted-<timestamp>.json` |
| Observable state       | `@Observable` + `@Environment(BookStore.self)` |
| Quick-add sheet        | `.sheet` with `.presentationDragIndicator(.visible)` |

## Known scope / not yet built

- **Barcode scanning** — not yet wired; design contemplates `AVFoundation` + `VNDetectBarcodesRequest`.
- **Library export / import** — tracked in `BACKLOG.md`.
- **iCloud sync** — `BookStore` writes to the local Documents directory only. For sync, switch persistence to SwiftData with CloudKit container.

See `BACKLOG.md` for the full list of post-review backlog items.

## Tests

```
xcodebuild test \
  -project Bedside.xcodeproj \
  -scheme Bedside \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2"
```

Or `⌘U` in Xcode. 32 tests across 4 suites currently pass in under a second.
