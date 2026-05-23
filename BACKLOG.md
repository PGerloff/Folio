# Bedside — Backlog

> Historical entries below predate the Bedside rename (May 2026) and reference `Folio` in file paths and namespaces. Those references are accurate for the commits cited; the current code uses `Bedside` everywhere. New backlog items should use the current naming.

Findings staged from the distinguished code review of 22 May 2026.

**Shipped:**
- Top-3 pre-submission fixes (Privacy Manifest, accessibility labels, PhotoPickerButton concurrency + cancel dismiss) — commit `2d2f507`
- **Sprint A** (H-1, M-1, M-2, M-5, M-6) — commit `f79233d`
- **Sprint B** (H-2, M-3, M-4, L-1, L-2, L-4) — commit `0b9ef1d`
- **Sprint C** (M-7, L-5, expanded test coverage) — see latest commit

Everything else is staged for future sessions.

Findings are tagged by severity:
- 🔴 **HIGH** — should land before App Store 1.0
- 🟠 **MEDIUM** — visible to TestFlight users or material polish
- 🟡 **LOW** — quality / hygiene
- 💡 **SUGGESTION** — forward-looking improvements

---

## Tier 1 — Security & Bugs (remaining)

### ✅ H-1 · Force-unwrap on Optional `book.year` — *shipped Sprint A*
**File:** `Components/BookShareContent.swift:14–16`
Replaced ternary with `if let` expression. Crash risk during share eliminated.

### ✅ M-1 · Empty `UIColorName` in `UILaunchScreen` — *shipped Sprint A*
**File:** `Info.plist:28–31`
Added `FolioBackground` named colour (`#F5ECD8`) to asset catalog and wired into launch screen. No more black flash on cold start.

---

## Tier 2 — Stability (remaining)

### ✅ H-2 · `BookStatus.dnf` is unreachable — *shipped Sprint B*
**File:** `Models/Models.swift:27`
Added `.dnf` to `BookStatus.pickable` between `.reading` and `.finished`. The Paused chip is now visible in `StatusPicker` everywhere it's used. Reading-flow order: Shop → To Read → Reading → Paused → Finished.

### ✅ M-2 · `StarsView` tap targets below 44pt HIG minimum — *shipped Sprint A*
**File:** `Components/StarsView.swift:29`
Padding now scales to a 44pt hit box on interactive stars; non-interactive Library tiles unaffected.

### ✅ M-3 · Unstructured `Task` in `PhotoPickerButton` — *shipped Sprint B*
**File:** `Components/PhotoPickerButton.swift`
Replaced `.onChange(of:) { Task { … } }` with `.task(id: pickerItem) { … }`. Rapid successive selections now auto-cancel the previous task before starting a new one; @State writes stay on MainActor for free.

---

## Tier 3 — Efficiency & Code Health

### ✅ M-4 · `bundleIdPrefix` mismatch in `project.yml` — *shipped Sprint B*
**File:** `project.yml:3`
Changed to `bundleIdPrefix: com.folioreader`. New `FolioTests` target shipped with the correct `com.folioreader.app.tests` bundle ID as a consequence.

### ✅ M-5 · Three dead settings rows visible to TestFlight users — *shipped Sprint A*
**File:** `Views/YouView.swift:135–137`
Notifications / Display & theme / Export library rows removed until implemented. Comment in code points back to this backlog. Clear library remains as the only settings action.

### ✅ L-1 · `LibraryView.count(_:)` recomputes all filters per render — *shipped Sprint B*
**File:** `Views/LibraryView.swift`
Replaced 5 separate filter passes with a single `chipCounts: [Filter: Int]` computed in one loop through `store.owned`. Cached in the `body` so all 5 chips read from the same dict.

### ✅ L-2 · `HomeView` computes favourite-finished filter twice — *shipped Sprint B*
**File:** `Views/HomeView.swift`
Filter lifted once at the top of `body` and passed into the section builder (renamed `favoritesSection(_:)`).

### 🟡 L-3 · `SWIFT_VERSION: "5.9"` misses Swift 6 concurrency diagnostics
**File:** `project.yml:11`
**Recommendation:** Upgrade to `SWIFT_VERSION: "6.0"`. Existing `@MainActor` annotations are already correct; migration cost should be low. Strict concurrency would have caught the `pickerItem` bug pre-review.

### ✅ L-4 · No tests — *shipped Sprint B + C*
**File:** `FolioTests/`
- **Sprint B** added the `FolioTests` target using Swift Testing and `BookStorePersistenceTests.swift` (7 tests).
- **Sprint C** added `BookShareContentTests.swift`, `CoverPhotoTests.swift`, and `OpenLibraryCoverFetchTests.swift` with a `MockURLProtocol` stub on an injected URLSession. Total across all four suites: **29 tests passing in 0.45s**.
- `BookStore.init` now takes optional `documentsDirectory` and `urlSession` parameters for isolation in tests.
- OL fetch suite is marked `@Suite(.serialized)` because its tests share a static mock handler; image tests use thread-safe `UIGraphicsImageRenderer` (the legacy `UIGraphicsBeginImageContext` API races under parallel test execution).

### 💡 S-1 · No schema migration strategy for `BookStore`
**File:** `Store/BookStore.swift:243–266`
**Issue:** Any model change triggers full reset via `backupCorruptedStore()`. Acceptable for beta, must be resolved before 1.0.
**Approach:** Introduce `version: Int` in `Persisted` struct; maintain an array of migration closures keyed by `from` version.

---

## Tier 4 — UX & Branding

### ✅ M-6 · No feedback when Open Library suggestions fail — *shipped Sprint A*
**File:** `Views/AddBookSheet.swift`
Added `suggestionsFailed` state. When both `fetchTrending` and `fetchClassics` return empty, the section shows a dashed-border message: *"Couldn't load suggestions right now. Check your connection and try reopening."* instead of blank space.

### ✅ M-7 · No haptic feedback on primary interactions — *shipped Sprint C*
**Files:** `Views/BookDetailView.swift`, `Views/AddBookSheet.swift`, `Views/ShopView.swift`
Mapping: `.impact(weight: .light)` for favourite toggle, rating change, and book added; `.success` for marking finished and marking as bought. All wired via iOS 17 `.sensoryFeedback` modifier.

### 🟠 M-8 · Dark mode hard-locked off
**File:** `FolioApp.swift:13` — `.preferredColorScheme(.light)`
**Issue:** Forces all users into light mode regardless of system preference. Accessibility and battery concern on OLED devices.
**Scope:** Real design work — needs dark variants of every `paper*`, `ink*`, and accent colour in `Theme.swift`.
**Interim:** Add a TestFlight release note acknowledging light-only.

### ✅ L-5 · Cover fetch produces a visual "pop" in BookDetailView — *shipped Sprint C*
**File:** `Components/CoverView.swift`
`CoverView` now renders the placeholder underneath and cross-fades the photo in via `.transition(.opacity)` + `.animation(.easeInOut(duration: 0.4), value: book.photoFilename)`. No store changes required.

---

## Suggested sequencing (for future sessions)

**✅ Sprint A — pre-1.0 must-haves — DONE**
H-1, M-1, M-2, M-5, M-6 shipped.

**✅ Sprint B — quality & resilience — DONE**
H-2, M-3, M-4, L-1, L-2, L-4 shipped.

**✅ Sprint C — polish — DONE**
M-7, L-5, and expanded test coverage shipped. 29 tests passing.

**Sprint D — feature (own work item):**
M-8 (dark mode design + implementation)

**Sprint E — pre-2.0 infra:**
L-3 (Swift 6 upgrade), S-1 (migration framework)
