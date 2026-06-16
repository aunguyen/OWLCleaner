import Foundation

/// Validates that a candidate path is safe to delete before any removal happens.
///
/// Catastrophic deletes come from path traversal and symlinks, not module logic,
/// so this type is the single chokepoint every deletion passes through — at scan
/// time *and again* at delete time (TOCTOU defense).
///
/// Canonicalization resolves the candidate's **parent** chain via POSIX `realpath`
/// (collapsing symlinks and `..`) while keeping the **leaf** literal. That is
/// deliberate: `FileManager.removeItem` on a symlink removes the link, not its
/// target, so a leaf symlink inside a safe root is safe to delete — but a parent
/// that symlinks *out* of the safe root must be rejected.
public struct SafetyGuard: Sendable {

    public enum Rejection: Equatable, Sendable {
        case outsideSafeRoot
        case isSafeRootItself
        case denylisted
    }

    public enum ValidationResult: Equatable, Sendable {
        case allowed(URL)
        case rejected(Rejection)

        public var isAllowed: Bool {
            if case .allowed = self { return true }
            return false
        }

        public var allowedURL: URL? {
            if case let .allowed(url) = self { return url }
            return nil
        }
    }

    public let safeRoots: [URL]
    public let denylist: [URL]

    private let resolvedSafeRoots: [[String]]
    private let resolvedDenylist: [[String]]

    public init(safeRoots: [URL], denylist: [URL] = SafetyGuard.defaultDenylist) {
        self.safeRoots = safeRoots
        self.denylist = denylist
        self.resolvedSafeRoots = safeRoots.map(Self.resolvedComponents)
        self.resolvedDenylist = denylist.map(Self.resolvedComponents)
    }

    public func validate(_ url: URL) -> ValidationResult {
        guard let canonical = Self.canonicalize(url) else {
            // Parent chain does not resolve (missing/inaccessible) — refuse.
            return .rejected(.outsideSafeRoot)
        }
        let c = canonical.pathComponents

        // 1. Denylist has the highest precedence: equal-to or descendant-of a
        //    protected root is always refused, even inside a (mis)configured root.
        for entry in resolvedDenylist where c == entry || Self.componentsContain(entry, candidate: c) {
            return .rejected(.denylisted)
        }

        // 2. The safe root itself is never deletable — only its contents.
        // 3. A strict descendant of a safe root is allowed.
        for root in resolvedSafeRoots {
            if c == root { return .rejected(.isSafeRootItself) }
            if Self.componentsContain(root, candidate: c) { return .allowed(canonical) }
        }

        return .rejected(.outsideSafeRoot)
    }

    // MARK: - Canonicalization

    /// Resolve the parent chain via `realpath` (symlinks + `..`), keep the leaf literal.
    /// Returns nil when the parent does not exist / is inaccessible.
    ///
    /// We deliberately do NOT call `standardizedFileURL` on the result: `realpath`
    /// has already collapsed `..` and symlinks, and `standardizedFileURL` would
    /// additionally strip the `/private` prefix (`/private/var` → `/var`), making
    /// the canonical candidate disagree with the realpath-resolved safe roots.
    static func canonicalize(_ url: URL) -> URL? {
        let leaf = url.lastPathComponent
        let parent = url.deletingLastPathComponent()
        guard let realParent = realPath(parent) else { return nil }
        return URL(fileURLWithPath: realParent).appendingPathComponent(leaf)
    }

    /// POSIX `realpath` for an existing path; nil if it does not resolve.
    static func realPath(_ url: URL) -> String? {
        url.path.withCString { cString in
            guard let resolved = Darwin.realpath(cString, nil) else { return nil }
            defer { free(resolved) }
            return String(cString: resolved)
        }
    }

    /// Path components for a configured root: resolved if it exists, else standardized.
    static func resolvedComponents(_ url: URL) -> [String] {
        if let resolved = realPath(url) {
            return URL(fileURLWithPath: resolved).pathComponents
        }
        return url.standardizedFileURL.pathComponents
    }

    /// True when `candidate` is a *strict* descendant of `root` (deeper, same prefix).
    static func componentsContain(_ root: [String], candidate: [String]) -> Bool {
        guard candidate.count > root.count else { return false }
        return Array(candidate.prefix(root.count)) == root
    }

    // MARK: - Default denylist

    /// Protected roots whose descendants must never be deleted. Chosen so that *no*
    /// legitimate safe root is nested within any entry (otherwise valid junk would
    /// be wrongly refused). Bare `~` and `/` are intentionally absent — they are
    /// handled by the allowlist + safe-root-itself rule, and listing them here would
    /// block everything.
    public static let defaultDenylist: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let system = [
            "/System", "/usr", "/bin", "/sbin", "/private/etc",
            "/Applications", "/Library/Frameworks", "/Library/Extensions",
            "/Library/Application Support",
        ].map { URL(fileURLWithPath: $0) }
        let user = [
            "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music", "Public",
            "Library/Application Support", "Library/Mail", "Library/Messages",
            "Library/Keychains", "Library/Preferences",
        ].map { home.appendingPathComponent($0) }
        return system + user
    }()
}
