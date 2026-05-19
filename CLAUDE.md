# Folio — Claude notes

SwiftUI iOS reading-list app. iOS 17+, file-based JSON persistence, no backend.

## Project structure

- `project.yml` — XcodeGen spec; the source of truth for the Xcode project
- `Folio.xcodeproj/` — **generated, gitignored**. Never commit; never `git add -f`.
- `FolioApp.swift` — app entry point
- `Models/` — `Book`, `BookStatus`, `Note`
- `Store/` — `BookStore` (@Observable, persists to `Documents/folio.json`), `OpenLibrary` (shared API client)
- `Theme/` — colours (`Folio.sienna`, `Folio.ink1`…), font helpers (`.folioDisplay`, `.folioUI`, `.folioMono`)
- `Components/` — reusable views (`MetaLabel`, `StatusPicker`, `PhotoPickerButton`, `CoverView`)
- `Views/` — screens (`RootView`, `HomeView`, `ShopView`, `LibraryView`, `YouView`, `AddBookSheet`, `ManualEntryView`, `BookDetailView`)
- `Assets.xcassets/` — `AppIcon`, `AccentColor`

Bundle ID: `com.folioreader.app`. Scheme: `Folio`.

## Build workflow

After **any** edit to `project.yml`:

```
xcodegen generate
```

Then open `Folio.xcodeproj` in Xcode and build. Commit `project.yml`, never the `.xcodeproj`.

See the `xcodegen-ios-app` skill for the full set of XcodeGen gotchas (Info.plist duplication, `path: .` pitfalls, bundle-ID install failures).

## Persistence

- Library JSON: `Documents/folio.json` (pretty-printed, sorted keys, ISO8601 dates)
- Cover photos: `Documents/covers/<book-uuid>.jpg` (re-encoded JPEG @ 0.85)
- Corrupted store on load → backed up to `folio.corrupted-<timestamp>.json` before reset; user is alerted via `lastErrorMessage`
- Save/load errors surface to the UI through `BookStore.lastErrorMessage`, displayed by `RootView` as an alert. Don't swallow them.

## Cover images

- Decoded `UIImage`s are cached in `BookStore.coverCache` (NSCache, 200-item limit). `loadCoverImage(_:)` is called from view bodies on every render, so it must stay cheap.
- Always invalidate the cache when deleting or replacing a photo (`invalidateCoverCache(_:)`).

## Open Library integration

All OL calls go through `OpenLibrary.request(url)` — handles the required `User-Agent` and a 10s timeout. See the `open-library-api` skill for endpoint quirks. Key points specific to Folio:

- Auto-cover fetch fires on save in `ManualEntryView` and on suggestion-tap in `AddBookSheet`, only when the user didn't supply a photo and both title + author are present
- "Popular right now" = 3 from `sort=currently_reading` + 2 random from `/subjects/classics`. Results cached for 1 hour per session.
- `/trending/*.json` returns HTML, not JSON — do not use it.

## SwiftUI conventions

- `@Observable` store (Observation framework, iOS 17+) — accessed via `@Environment(BookStore.self)`
- Mutations from async contexts wrap state changes in `await MainActor.run { ... }`
- Detail / add sheets use `.sheet(item:)` with `BookID` wrapper for UUID identity
- Destructive actions: single tap → confirmation alert (no double-tap-to-confirm pattern)

## Naming choices

- The "Add" tab (formerly "Shop") avoids ecommerce vibes — keep neutral language ("Add a book", not "Buy", "Cart", "Shop").
- The shopping-list status still exists in the model (`BookStatus.shopping`) — it's the "want to buy" bucket.

## Commit style

Short imperative subject, no body unless needed. Co-author trailer:

```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Don't commit unprompted — wait to be asked.
