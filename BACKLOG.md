# Folio — Backlog

Findings staged from the distinguished code review of 22 May 2026.
The top-3 pre-submission fixes (Privacy Manifest, accessibility labels,
PhotoPickerButton concurrency + cancel dismiss) have already shipped.
Everything below is staged for future sessions.

Findings are tagged by severity:
- 🔴 **HIGH** — should land before App Store 1.0
- 🟠 **MEDIUM** — visible to TestFlight users or material polish
- 🟡 **LOW** — quality / hygiene
- 💡 **SUGGESTION** — forward-looking improvements

---

## Tier 1 — Security & Bugs (remaining)

### 🔴 H-1 · Force-unwrap on Optional `book.year`
**File:** `Components/BookShareContent.swift:14–16`
**Issue:** Safe today (nil-checked in ternary) but brittle. Any refactor that reorders the condition turns it into a runtime crash during share.
**Fix:**
```swift
let byline = if let year = book.year {
    "by \(book.author) (\(year))"
} else {
    "by \(book.author)"
}
```

### 🟠 M-1 · Empty `UIColorName` in `UILaunchScreen`
**File:** `Info.plist:28–31`
**Issue:** `<key>UIColorName</key><string></string>` — empty string is invalid. Causes a black launch flash on some iOS versions.
**Fix:** Either remove `UIColorName` entirely (defaults to white) or add a `FolioBackground` named colour to the asset catalog matching `Folio.paper0` (`#F5ECD8`) and reference it here.

---

## Tier 2 — Stability (remaining)

### 🔴 H-2 · `BookStatus.dnf` is unreachable
**File:** `Models/Models.swift:27` + entire Views layer
**Issue:** `.dnf` exists in the model, has a status dot colour, appears in share text, and counts toward filters — but `StatusPicker` only shows the four `.pickable` statuses and no long-press handler exists anywhere. Comment promises long-press; no implementation.
**Options:**
- **Implement:** Add `.onLongPressGesture` to `StatusPicker` rows that surfaces `.dnf` as an extra option.
- **Remove:** Strip `.dnf` from the model, `Theme.statusDot`, and `BookShareContent` until ready.

### 🟠 M-2 · `StarsView` tap targets below 44pt HIG minimum
**File:** `Components/StarsView.swift:29`
**Issue:** 8pt stars with 3pt padding = 14pt tap target. 18pt stars = 24pt. Apple HIG requires 44×44pt minimum.
**Fix:**
```swift
.padding(onChange != nil ? max(3, (44 - size) / 2) : 0)
```
Likely flagged in App Store accessibility audit.

### 🟠 M-3 · Unstructured `Task` in `PhotoPickerButton` — rapid-selection race
**File:** `Components/PhotoPickerButton.swift:39`
**Issue:** New `Task {}` fires on each `.onChange(of: pickerItem)`. Rapid selection runs multiple concurrent tasks, each writing a photo + mutating `BookStore`.
**Fix:** Switch the entire pattern to `.task(id: pickerItem)` which auto-cancels previous tasks on change.

---

## Tier 3 — Efficiency & Code Health

### 🟠 M-4 · `bundleIdPrefix` mismatch in `project.yml`
**File:** `project.yml:3` — `bundleIdPrefix: com.folio` (stale)
**Fix:** Change to `bundleIdPrefix: com.folioreader`. Doesn't affect current build but propagates to any future XcodeGen-derived target (widget, share extension, test target).

### 🟠 M-5 · Three dead settings rows visible to TestFlight users
**File:** `Views/YouView.swift:135–137`
**Issue:** "Notifications", "Display & theme", "Export library" are tappable, show chevrons, do nothing.
**Options:**
- Implement stubs that toast "Coming soon"
- Add a `isComingSoon: Bool` flag to `settingsRow` that greys the row and hides the chevron
- Remove until implemented (cleanest for TestFlight)

### 🟡 L-1 · `LibraryView.count(_:)` recomputes all filters per render
**File:** `Views/LibraryView.swift:34–42`
**Issue:** 5 chips × full filter pass each. Already noted in a prior review and still unfixed.
**Fix:** Lift counts to a `chipCounts: [Filter: Int]` computed property called once per body render.

### 🟡 L-2 · `HomeView` computes favourite-finished filter twice
**File:** `Views/HomeView.swift:25, 184`
**Fix:** Compute `store.favorites.filter { $0.status == .finished }` once and pass into the section builder.

### 🟡 L-3 · `SWIFT_VERSION: "5.9"` misses Swift 6 concurrency diagnostics
**File:** `project.yml:11`
**Recommendation:** Upgrade to `SWIFT_VERSION: "6.0"`. Existing `@MainActor` annotations are already correct; migration cost should be low. Strict concurrency would have caught the `pickerItem` bug pre-review.

### 🟡 L-4 · No tests
**File:** Entire project
**Highest-value tests to add first:**
1. `BookStorePersistenceTests` — save → terminate → reload round-trip
2. `BookShareContentTests` — `text(for:)` output for each status × rating combination
3. Cover photo write/read round-trip
**Fix:** Add a `FolioTests` target to `project.yml` and stub one test before TestFlight build 0.2.0.

### 💡 S-1 · No schema migration strategy for `BookStore`
**File:** `Store/BookStore.swift:243–266`
**Issue:** Any model change triggers full reset via `backupCorruptedStore()`. Acceptable for beta, must be resolved before 1.0.
**Approach:** Introduce `version: Int` in `Persisted` struct; maintain an array of migration closures keyed by `from` version.

---

## Tier 4 — UX & Branding

### 🟠 M-6 · No feedback when Open Library suggestions fail
**File:** `Views/AddBookSheet.swift:30–71`
**Issue:** API failure → empty suggestions array silently. Users in airplane mode see a partial sheet with no explanation.
**Fix:** Add `suggestionsError: Bool` state. When both `fetchTrending` and `fetchClassics` return empty, show: *"Couldn't load suggestions right now."*

### 🟠 M-7 · No haptic feedback on primary interactions
**File:** `Views/BookDetailView.swift`, `Views/AddBookSheet.swift`, `Views/ShopView.swift`
**Issue:** Adding a book, toggling favourite, rating a book, marking as bought — none produce haptics.
**Fix:** Use `.sensoryFeedback(.impact(weight: .light), trigger: …)` on key state changes. iOS 17+ API, drop-in.

### 🟠 M-8 · Dark mode hard-locked off
**File:** `FolioApp.swift:13` — `.preferredColorScheme(.light)`
**Issue:** Forces all users into light mode regardless of system preference. Accessibility and battery concern on OLED devices.
**Scope:** Real design work — needs dark variants of every `paper*`, `ink*`, and accent colour in `Theme.swift`.
**Interim:** Add a TestFlight release note acknowledging light-only.

### 🟡 L-5 · Cover fetch produces a visual "pop" in BookDetailView
**File:** `Views/BookDetailView.swift:88–123`
**Issue:** When a book is added without a photo, the detail view opens with the placeholder tile; the auto-fetched cover appears 1–8 seconds later with no transition.
**Fix:** Apply `.redacted(reason: .placeholder)` on `CoverView` while `book.photoFilename == nil && isFetching`. Requires plumbing an `isFetching` state into the store keyed by book id.

---

## Suggested sequencing (for future sessions)

**Sprint A — pre-1.0 must-haves (est. 1 day):**
H-1, M-1, M-2, M-5, M-6

**Sprint B — quality & resilience (est. 2 days):**
H-2 (decide), M-3, M-4, L-1, L-2, L-4 (initial test target)

**Sprint C — polish (est. 2–3 days):**
M-7, L-5

**Sprint D — feature (own work item):**
M-8 (dark mode design + implementation)

**Sprint E — pre-2.0 infra:**
L-3 (Swift 6 upgrade), S-1 (migration framework)
