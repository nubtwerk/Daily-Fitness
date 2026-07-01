import SwiftData

extension ModelContext {
    /// Saves pending changes, logging (never swallowing) any failure.
    /// - Returns: `true` on success (or when there was nothing to save), `false` if the save threw.
    @discardableResult
    func saveOrLog(_ operation: StaticString) -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            AppLog.persistence.error(
                "Save failed (\(operation, privacy: .public)): \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    /// Saves pending changes and, on failure, surfaces a calm, user-facing message via the presenter.
    /// Use on the live-workout / user-authored paths where a silent failure would lose the user's work.
    @MainActor
    func saveOrPresent(
        _ operation: StaticString,
        presenter: ErrorPresenter,
        title: String,
        message: String
    ) {
        if !saveOrLog(operation) {
            presenter.present(title: title, message: message)
        }
    }
}
