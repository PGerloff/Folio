# Bedside — Claude notes

SwiftUI iOS reading-list app. iOS 17+, file-based JSON persistence, no backend.

> Previously named **Folio** (renamed to Bedside in May 2026). The PRODUCT_BUNDLE_IDENTIFIER is kept as `com.folioreader.app` from the rename — that's intentional, not stale. The repo folder is still called `Folio/` on disk until the next git move; everything inside it builds and ships as Bedside.

## Project structure

- `project.yml` — XcodeGen spec; the source of truth for the Xcode project
- `Bedside.xcodeproj/` — **generated, gitignored**. Never commit; never `git add -f`.
- `BedsideApp.swift` — app entry point
- `Models/` — `Book`, `BookStatus`, `Note`
- `Store/` — `BookStore` (@Observable, persists to `Documents/bedside.json`), `OpenLibrary` (shared API client)
- `Theme/` — colours (`Bedside.sienna`, `Bedside.ink1`…), font helpers (`.bedsideDisplay`, `.bedsideUI`, `.bedsideMono`)
- `Components/` — reusable views (`MetaLabel`, `StatusPicker`, `PhotoPickerButton`, `CoverView`)
- `Views/` — screens (`RootView`, `HomeView`, `ShopView`, `LibraryView`, `YouView`, `AddBookSheet`, `ManualEntryView`, `BookDetailView`)
- `Assets.xcassets/` — `AppIcon`, `AccentColor`, `BedsideBackground` (launch screen)
- `BedsideTests/` — Swift Testing target

Bundle ID: `com.folioreader.app`. Scheme: `Bedside`. App Store listing name: **Bedside: Your Books**. Home-screen label (`CFBundleDisplayName`): `Bedside`.

## Build workflow

After **any** edit to `project.yml`:

```
xcodegen generate
```

Then open `Bedside.xcodeproj` in Xcode and build. Commit `project.yml`, never the `.xcodeproj`.

See the `xcodegen-ios-app` skill for the full set of XcodeGen gotchas (Info.plist duplication, `path: .` pitfalls, bundle-ID install failures).

## Persistence

- Library JSON: `Documents/bedside.json` (pretty-printed, sorted keys, ISO8601 dates)
- Cover photos: `Documents/covers/<book-uuid>.jpg` (re-encoded JPEG @ 0.85)
- **Legacy migration:** on first launch after the rename, if `bedside.json` is missing and `folio.json` exists, the legacy file is moved to the new name once. Idempotent and a no-op for new installs.
- Corrupted store on load → backed up to `bedside.corrupted-<timestamp>.json` before reset; user is alerted via `lastErrorMessage`
- Save/load errors surface to the UI through `BookStore.lastErrorMessage`, displayed by `RootView` as an alert. Don't swallow them.

## Cover images

- Decoded `UIImage`s are cached in `BookStore.coverCache` (NSCache, 200-item limit). `loadCoverImage(_:)` is called from view bodies on every render, so it must stay cheap.
- Always invalidate the cache when deleting or replacing a photo (`invalidateCoverCache(_:)`).

## Open Library integration

All OL calls go through `OpenLibrary.request(url)` — handles the required `User-Agent` (`Bedside/1.0 (+https://risingtidecyber.com.au)`) and a 10s timeout. See the `open-library-api` skill for endpoint quirks. Key points specific to Bedside:

- Auto-cover fetch fires on save in `ManualEntryView` and on suggestion-tap in `AddBookSheet`, only when the user didn't supply a photo and both title + author are present
- "Popular right now" = 3 from `sort=currently_reading` + 2 random from `/subjects/classics`. Results cached for 1 hour per session.
- `/trending/*.json` returns HTML, not JSON — do not use it.

## SwiftUI conventions

- `@Observable` store (Observation framework, iOS 17+) — accessed via `@Environment(BookStore.self)`
- Mutations from async contexts wrap state changes in `await MainActor.run { ... }` (or annotate the method `@MainActor`)
- Detail / add sheets use `.sheet(item:)` with `BookID` wrapper for UUID identity
- Destructive actions: single tap → confirmation alert (no double-tap-to-confirm pattern)
- Haptics via `.sensoryFeedback`: `.impact(weight: .light)` for toggles/rating/add, `.success` for finished/bought.

## Naming choices

- The "Add" tab (formerly "Shop") avoids ecommerce vibes — keep neutral language ("Add a book", not "Buy", "Cart", "Shop").
- The shopping-list status still exists in the model (`BookStatus.shopping`) — it's the "want to buy" bucket.

## Commit style

Short imperative subject, no body unless needed. Co-author trailer:

```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Don't commit unprompted — wait to be asked.

## Tests

29 tests across 4 suites, all in `BedsideTests/`:
- `BookStorePersistenceTests` (8 — add/update/remove/notes/favourite-authors round-trip, corrupted-JSON backup, clean first launch, legacy folio.json → bedside.json migration)
- `BookShareContentTests` (9 — every status × rating combination)
- `CoverPhotoTests` (7 — write/read/replace/clear/delete cascades, fail-loud on non-image bytes)
- `OpenLibraryCoverFetchTests` (6, serialised — happy path, no match, 404, network error, skip-when-photo-exists, bad-author skip)

Run from Xcode (`⌘U`) or CLI: `xcodebuild test -project Bedside.xcodeproj -scheme Bedside -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2"`.
