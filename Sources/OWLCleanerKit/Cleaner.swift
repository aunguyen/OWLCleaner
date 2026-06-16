import Foundation

/// Performs deletions, re-validating every item through the SafetyGuard at delete
/// time (not just at scan time) so a path swapped between scan and clean is caught.
public struct Cleaner: Sendable {
    private let safetyGuard: SafetyGuard
    private let remover: FileRemoving

    public init(safetyGuard: SafetyGuard, remover: FileRemoving = SystemFileRemover()) {
        self.safetyGuard = safetyGuard
        self.remover = remover
    }

    public func clean(_ items: [CleanupItem], dryRun: Bool) -> CleanOutcome {
        var outcome = CleanOutcome()
        for item in items {
            switch safetyGuard.validate(item.url) {
            case let .rejected(rejection):
                outcome.failures.append(
                    CleanFailure(url: item.url, reason: "blocked by safety guard (\(rejection))")
                )

            case let .allowed(url):
                if dryRun {
                    outcome.removed.append(url)
                    outcome.freedBytes += item.sizeBytes
                    continue
                }
                do {
                    switch item.removalMode {
                    case .delete: try remover.removeItem(at: url)
                    case .trash: try remover.trashItem(at: url)
                    }
                    outcome.removed.append(url)
                    outcome.freedBytes += item.sizeBytes
                } catch {
                    outcome.failures.append(
                        CleanFailure(url: item.url, reason: error.localizedDescription)
                    )
                }
            }
        }
        return outcome
    }
}
