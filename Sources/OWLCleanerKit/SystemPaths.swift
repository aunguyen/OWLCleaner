import Foundation

/// Helpers for resolving the current user's standard junk locations.
public enum SystemPaths {
    /// The per-user Darwin directory for a `confstr` key such as
    /// `_CS_DARWIN_USER_TEMP_DIR` or `_CS_DARWIN_USER_CACHE_DIR`
    /// (e.g. `/var/folders/xx/…/T` and `…/C`).
    public static func darwinUserDir(_ key: Int32) -> URL? {
        let size = confstr(key, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        let written = confstr(key, &buffer, size)
        guard written > 0 else { return nil }
        let path = String(cString: buffer)
        return path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
    }

    public static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
}
