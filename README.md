# 🦉 OWLCleaner

A native macOS app (SwiftUI, Swift 6) that reclaims disk space by scanning
known-safe junk locations, previewing everything with sizes, and cleaning only
on explicit confirmation. A focused, CleanMyMac-style cleaner for your own Mac.

## Modules

| Module | What it cleans | How |
|--------|----------------|-----|
| **System & App Junk** | User & app caches, logs, per-user temp dirs, user-deletable system caches | Hard delete (regenerable) |
| **Trash** | `~/.Trash` and per-volume `.Trashes/$UID` | Hard delete |
| **Developer** | Xcode DerivedData & device support, simulator caches, npm/Yarn/pip/Homebrew/CocoaPods/Gradle caches | Hard delete |
| **Large & Old Files** | Big files in a folder you choose | Moved to **Trash** (recoverable), opt-in only |

## Safety

Deletion is gated by a single, adversarially-tested `SafetyGuard`:

- Every candidate path is **canonicalized via `realpath`** (parent chain resolved,
  leaf kept literal) and must resolve **strictly inside** a configured safe root.
- A safe root itself is never deletable — only its contents.
- A hardcoded **denylist** protects precious locations (`/System`, `~/Documents`,
  `~/Library/Application Support`, …).
- The guard is **re-validated at delete time** (not just at scan), defeating
  time-of-check/time-of-use swaps.
- Deletes only **top-level items** via `FileManager.removeItem` (which removes a
  symlink itself, never its target).
- Items the app cannot delete (root-owned system caches) are surfaced as
  *"needs elevated access"* and never touched.
- A **Dry-run** toggle (Settings) simulates without deleting anything.

## Build & run

```sh
# Run tests
swift test

# Build, bundle into a signed .app, and launch
./Scripts/run.sh

# Just build the bundle (build/OWLCleaner.app)
./Scripts/make_app.sh
```

The app is signed with a stable Apple Development identity so the **Full Disk
Access** grant survives rebuilds. Override the identity if needed:

```sh
OWL_SIGN_ID="<identity hash or name>" ./Scripts/make_app.sh
```

### Grant Full Disk Access (one-time)

A real cache cleaner needs to read system/app caches. After first launch:

1. **Settings → Permissions → Open Full Disk Access settings…** (or System
   Settings → Privacy & Security → Full Disk Access).
2. Add and enable **OWLCleaner**.
3. Relaunch.

Without it, OWLCleaner still cleans everything reachable as your user; system
locations are shown as "needs elevated access".

## Architecture

- **`OWLCleanerKit`** — pure, fully unit-tested engine: models, `SafetyGuard`,
  `Cleaner`, `DiskSizer`, `DirectoryJunkScanner`, and the four modules.
- **`OWLCleaner`** — SwiftUI app: `AppModel` (`@MainActor @Observable`) runs
  scans concurrently off the main actor via a `TaskGroup` and cleans each
  module's selection through that module's own guard.

Design spec: [`docs/superpowers/specs/2026-06-17-owlcleaner-design.md`](docs/superpowers/specs/2026-06-17-owlcleaner-design.md).

## Out of scope (v1)

Privileged helper for root-owned system caches, app uninstaller, malware scan,
menu-bar widget, scheduling, auto-update, notarization.
