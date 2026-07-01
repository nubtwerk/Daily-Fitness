import SwiftUI

/// A failure worth surfacing to the user (calm, non-technical copy).
struct UserFacingError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func == (lhs: UserFacingError, rhs: UserFacingError) -> Bool { lhs.id == rhs.id }
}

/// App-wide channel for surfacing recoverable failures (e.g. a persistence save that didn't land)
/// to the user instead of swallowing them. Injected via `DependencyContainer` and rendered once at
/// the app root with `.dfErrorAlert(_:)`.
@Observable
@MainActor
final class ErrorPresenter {
    var current: UserFacingError?

    func present(_ error: UserFacingError) {
        current = error
    }

    func present(title: String, message: String) {
        current = UserFacingError(title: title, message: message)
    }

    func dismiss() {
        current = nil
    }
}

extension View {
    /// Renders the presenter's current error as a calm alert. Attach once, near the app root.
    func dfErrorAlert(_ presenter: ErrorPresenter) -> some View {
        alert(
            presenter.current?.title ?? "Something went wrong",
            isPresented: Binding(
                get: { presenter.current != nil },
                set: { if !$0 { presenter.dismiss() } }
            ),
            presenting: presenter.current
        ) { _ in
            Button("OK", role: .cancel) { presenter.dismiss() }
        } message: { error in
            Text(error.message)
        }
    }
}
