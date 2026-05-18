# Folio · iOS (Swift / SwiftUI)

Native SwiftUI port of the [Folio](../folio/Folio%20Reading%20App.html) reading-list Beta.

## What's here

- **SwiftUI** views (iOS 17+) — uses the new `@Observable` macro and `PhotosPicker`.
- **No external dependencies.** Just Foundation + SwiftUI + PhotosUI + UIKit (the last only for `UIImagePickerController` camera capture).
- **File-based persistence.** Books + favorite authors are stored as JSON at
  `Documents/folio.json`. Cover photos live as JPEGs at `Documents/covers/<UUID>.jpg`.

## Setup (Xcode 15+)

1. **Create a new app target.** In Xcode: `File → New → Project… → iOS → App`.
   - Product name: `Folio`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we manage persistence ourselves)
   - Minimum deployment: **iOS 17.0**

2. **Replace the generated source with this folder.** In Finder, drag the
   contents of `ios/Folio/` into the new project's `Folio` group, choosing
   **"Copy items if needed"** and adding to the **Folio** target.
   - Delete the auto-generated `ContentView.swift` and `FolioApp.swift` first
     (this folder ships its own `FolioApp.swift`).

3. **Configure `Info.plist`.** Either replace Xcode's auto-generated Info entries
   with the provided `Info.plist`, or copy these keys into the target's
   *Info* tab → *Custom iOS Target Properties*:
   - `NSCameraUsageDescription` — required for the in-app camera shutter.
   - `NSPhotoLibraryUsageDescription` — optional; only used by legacy pickers.

4. **Build & run.** Choose an iPhone simulator (e.g. iPhone 15) or your device.
   Camera capture only works on a real device — the simulator falls back to
   "Choose from Library."

## Architecture

```
Folio/
├── FolioApp.swift              @main — wires up BookStore in the environment
├── Info.plist                  camera + photo library usage strings
├── Models/Models.swift         Book, BookStatus, CoverColor, Note
├── Store/BookStore.swift       @Observable persistence layer
├── Theme/Theme.swift           Folio palette, fonts, shared modifiers
├── Components/
│   ├── CoverView.swift         photo-or-tile cover renderer
│   ├── StarsView.swift         1–5 stars, read-only or tappable
│   ├── StatusPicker.swift      Shop / To Read / Reading / Finished segmented control
│   └── PhotoPickerButton.swift  combined camera + library picker
└── Views/
    ├── RootView.swift          TabView shell, sheet routing
    ├── HomeView.swift          shopping-first landing screen
    ├── ShopView.swift          buy list with one-tap "mark as bought"
    ├── LibraryView.swift       3-column grid, filter chips
    ├── BookDetailView.swift    cover hero, status, rating, notes
    ├── AddBookSheet.swift      quick-add bottom sheet
    ├── ManualEntryView.swift   full form with photo capture
    └── YouView.swift           stats, favorite authors, settings
```

## Feature mapping (React Beta → Swift)

| Beta concept              | iOS implementation |
| ---                       | --- |
| `localStorage` JSON       | `JSONEncoder` → `Documents/folio.json` |
| Photo data URLs           | JPEGs written to `Documents/covers/` via `UIImage.jpegData(0.85)` |
| React `Context`           | `@Observable` + `@Environment(BookStore.self)` |
| Tab bar (custom HTML)     | `TabView` |
| Quick-add sheet           | `.sheet` with `.presentationDragIndicator(.visible)` |
| Heart toggles             | SF Symbols `heart`/`heart.fill` |
| Star rating               | SF Symbols `star`/`star.fill`, tappable |
| Status segmented control  | `StatusPicker` custom view |
| Newsreader display serif  | New York via `.system(design: .serif)` |
| Geist UI sans             | SF Pro (system default) |
| Geist Mono                | SF Mono via `.system(design: .monospaced)` |

## Known scope / not yet built

- **Barcode scanning** — placeholder card; the design contemplates `AVFoundation` +
  `VNDetectBarcodesRequest`.
- **Goodreads import / library export** — stubbed in the settings list.
- **Dark mode palette** — the React Beta defines a "Library at Night" palette;
  port it by adding a `.dark` branch to `Folio` in `Theme/Theme.swift`.
- **iCloud sync** — `BookStore` writes to the local Documents directory only.
  For sync, switch persistence to SwiftData with CloudKit container, or
  replicate the JSON file via `NSUbiquitousKeyValueStore` / `FileManager`'s
  iCloud URLs.

## Running on device

Camera capture requires a real device. After signing the target with your
Apple ID:

```
Product → Destination → <Your iPhone>
Product → Run
```

The first time you tap the camera icon, iOS will prompt for camera permission
using the `NSCameraUsageDescription` string above.
