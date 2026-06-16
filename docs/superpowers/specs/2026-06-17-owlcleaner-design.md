# OWLCleaner — Design Spec

**Date:** 2026-06-17
**Status:** Approved (brainstorming gate passed)
**Platform:** macOS 26+ (Apple Silicon), Swift 6.3, SwiftUI

---

## 1. Summary

OWLCleaner is a native SwiftUI macOS app that reclaims disk space by scanning known-safe
junk locations, previewing everything with sizes, and cleaning only on explicit user
confirmation. It runs **un-sandboxed** with **Full Disk Access** so it can reach the
caches/temp/trash locations a real cleaner needs.

Four modules:

1. **System & app junk** — user caches, app caches, logs, user temp dirs.
2. **Trash** — empties `~/.Trash` and per-volume `.Trashes/$UID`.
3. **Developer caches** — Xcode DerivedData / DeviceSupport, npm / yarn / pip / Homebrew caches.
4. **Large & old files** — finder over a user-chosen folder; moves selections to Trash (recoverable).

## 2. Non-goals (v1, YAGNI)

- Privileged helper (SMAppService + XPC) for root-owned system caches — deferred future phase.
- App uninstaller, malware scan, menu-bar widget, scheduling, auto-update, notarization/distribution.

## 3. Architecture

Swift Package (`Package.swift`) with three targets:

| Target | Kind | Responsibility |
|--------|------|----------------|
| `OWLCleanerKit` | library | Pure engine: models, modules, `SafetyGuard`, `Cleaner`, disk sizing. No UI, no global state. Fully unit-testable. |
| `OWLCleaner` | executable | SwiftUI app, view models. Depends on Kit. |
| `OWLCleanerKitTests` | test | Adversarial unit tests; SafetyGuard first. |

**Build → runnable `.app`:**
- `swift build -c release` produces the executable.
- `Scripts/make_app.sh` assembles `OWLCleaner.app` (Info.plist, icon, binary) and **codesigns with one
  stable identity** (default: an existing Apple Development identity, overridable via `OWL_SIGN_ID`) so the
  Full Disk Access grant survives rebuilds.
- `Scripts/run.sh` = build → bundle → launch.

## 4. Core model (all `Sendable` value types)

```
CleanupItem      { id, url, displayName, sizeBytes (disk-allocated), category, moduleID,
                   isProtected, note, defaultSelected }
CleanupCategory  { id, title, systemImage }
ModuleScanResult { moduleID, items, totalBytes, skipped: [SkippedPath] }
SkippedPath      { url, reason (permissionDenied / outsideSafeRoot / inUse / needsElevatedAccess) }
CleanOutcome     { removedItems, freedBytes, failures: [(url, error)] }
```

`CleanupModule` protocol:
```
protocol CleanupModule: Sendable {
    var id: String { get }
    var title: String { get }
    var systemImage: String { get }
    func scan(progress: @Sendable (Double) -> Void) async -> ModuleScanResult
}
```

## 5. SafetyGuard — the crown jewel

Catastrophic deletes come from path traversal and symlinks, not module logic. The guard is **pure**
(injected `FileManager`) and **TDD'd hard** against adversarial inputs before any module is built.

`validate(_ url:) -> ValidationResult` rules, in order:
1. **Canonicalize** the candidate path (`realpath` / resolve symlinks + standardize) **before** any check.
2. Reject if the resolved path is **not contained within** any configured safe root.
3. Reject a **safe root itself** — only its *contents* are eligible (never delete `~/Library/Caches`).
4. Reject anything matching the **critical denylist** (`/`, `/System`, `/usr`, `/bin`, `~`, `~/Library`
   bare, `~/Documents`, `~/Desktop`, etc.).
5. **Re-validate at delete time** (not just scan) to defeat TOCTOU swaps.

`Cleaner`:
- Deletes only **top-level items** via `FileManager.removeItem(at:)` — never hand-rolled recursive unlink.
- Large & old files use `FileManager.trashItem(at:)` (recoverable), never `removeItem`.
- Permission-denied / in-use items are skipped and reported, never force-deleted.

**Adversarial tests (must pass before modules):** `..` traversal, symlink→`/`, symlink→home,
path resolving outside roots, the safe-root itself, denylisted paths, nested symlink chains.

## 6. Deletion semantics

| Module | Action | Auto-selected? |
|--------|--------|----------------|
| System & app junk | hard-delete contents (regenerable) | yes |
| Developer caches | hard-delete contents (regenerable) | yes |
| Trash | `removeItem` each entry in trash dirs | yes |
| Large & old files | `trashItem` (recoverable) | **no** — explicit review only |

Always: preview with per-item checkboxes → confirmation dialog showing total size + count → clean.
**Dry-run toggle** in Settings simulates without deleting.

## 7. Safe roots per module

- **System & app junk:** `~/Library/Caches/*`, `~/Library/Logs/*`, user temp dirs from
  `confstr(_CS_DARWIN_USER_CACHE_DIR)` and `_CS_DARWIN_USER_TEMP_DIR` (`/var/folders/.../C`, `/T`),
  best-effort user-writable entries under `/Library/Caches` (skip perm-denied).
- **Trash:** `~/.Trash`, `/Volumes/*/.Trashes/<uid>`.
- **Developer:** `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/Xcode/iOS DeviceSupport`,
  `~/Library/Caches/com.apple.dt.Xcode`, `~/.npm/_cacache`, `~/Library/Caches/Yarn`,
  `~/Library/Caches/pip`, `~/Library/Caches/Homebrew` / `$(brew --cache)`.
- **Large & old:** user-selected folder only (security-scoped); never a system root.

## 8. Concurrency (Swift 6 strict, designed in)

Scanning runs off-main via `async/await` + `TaskGroup` (one child task per module). Modules stream
progress via the `@Sendable` closure. All result types are `Sendable` value types. UI state lives on a
`@MainActor` view model that awaits the task group and publishes results.

## 9. Scope boundary (explicit user-approved decision)

v1 cleans only what the app can reach **as the user with Full Disk Access** — essentially all of
`~/Library`, user temp dirs, all Trash, and dev caches. **Root-owned system caches and SIP-protected
paths are detected, surfaced as "skipped — needs elevated access," and never touched.** A privileged
helper to clean those is a documented future phase.

## 10. UI (polished, CleanMyMac-style)

- **Sidebar:** Smart Scan (aggregate) • System Junk • Trash • Developer • Large & Old; owl mark at bottom.
- **Main pane:** animated circular scan gauge + live byte counter → category breakdown with expandable,
  checkable item lists → prominent **Clean** button → "Freed X" completion state.
- Dark-mode-native, SF Symbols, `.regularMaterial` chrome, smooth transitions.
- **Settings:** dry-run toggle; Large & old size/age thresholds; per-module exclusions.

## 11. Risks & day-one validations

- **FDA + signing:** FDA grants key on the code-signing designated requirement. **Day-one test:** build,
  grant FDA, rebuild, confirm `/Library/Caches` still readable. Using a stable Apple Development identity
  (not per-build ad-hoc) keeps the requirement constant. Resolve before building on top.
- **No public empty-Trash API:** enumerate trash dirs and `removeItem` each, skipping perm-denied.

## 12. Implementation plan (build sequence)

1. **Scaffold** — `Package.swift`, target dirs, `.gitignore`, build/run scripts.
2. **Kit foundation (TDD)** — models + `SafetyGuard` + `Cleaner`; adversarial tests green first.
3. **Reference module** — `SystemJunkModule` end-to-end, integration-tested against a temp dir tree.
4. **App shell** — SwiftUI sidebar + scan/clean view model wired to the System module; `make_app.sh`;
   **FDA persistence test**.
5. **Fan out** — `TrashModule`, `DeveloperModule` (same shape).
6. **Large & old** — finder + `trashItem`, built last.
7. **UI polish** — gauge animation, materials, completion state, Settings.
8. **Verify** — `swift test` green; launch the bundled app; scan + dry-run clean observed.

## 13. Testing strategy

- **Unit:** SafetyGuard adversarial suite (highest priority); model sizing.
- **Integration:** each module scans a synthesized temp directory tree with known sizes/symlinks; assert
  correct items found, safe roots respected, symlinks not escaped, dry-run deletes nothing.
- **Manual:** bundled app launch, real scan, dry-run clean, FDA grant persistence.
