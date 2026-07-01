import AuthenticationServices
import Foundation
import Supabase
import SwiftData
import UIKit

@MainActor
final class AuthService: NSObject {
    private let userSession: UserSession
    private let syncEngine: SyncEngine
    private var continuation: CheckedContinuation<Void, Error>?

    private var client: SupabaseClient {
        SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
    }

    init(userSession: UserSession, syncEngine: SyncEngine) {
        self.userSession = userSession
        self.syncEngine = syncEngine
        super.init()
    }

    func restoreSession() async {
        guard !AppConfig.supabaseAnonKey.isEmpty else { return }
        do {
            let session = try await client.auth.session
            userSession.isAuthenticated = true
            userSession.supabaseUserId = session.user.id
            syncEngine.setAuthenticated(true)
        } catch {
            userSession.isAuthenticated = false
        }
    }

    func signInWithApple() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        userSession.isAuthenticated = false
        userSession.supabaseUserId = nil
        syncEngine.setAuthenticated(false)
    }

    func deleteAccount(context: ModelContext) async throws {
        guard userSession.isAuthenticated else { return }

        // Remote: sign out (full delete requires server-side admin function in Supabase)
        try? await client.auth.signOut()

        let wiped = wipeLocalData(context: context)

        userSession.isAuthenticated = false
        userSession.supabaseUserId = nil
        userSession.isPro = false
        syncEngine.setAuthenticated(false)

        // Surface a partial wipe — the user was told their data is gone.
        if !wiped { throw AuthError.dataDeletionFailed }
    }

    func mergeLocalData(context: ModelContext) async throws {
        let userId = userSession.effectiveUserId
        let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
        for session in sessions {
            session.userId = userId
            session.syncStatus = .pending
        }
        let routines = try context.fetch(FetchDescriptor<RoutineEntity>())
        for routine in routines {
            routine.userId = userId
            routine.syncStatus = .pending
        }
        try context.save()
        try await syncEngine.flush(context: context)
        try await syncEngine.pullRemoteChanges(since: nil, context: context)
    }

    @discardableResult
    private func wipeLocalData(context: ModelContext) -> Bool {
        deleteAll(WorkoutSessionEntity.self, context: context)
        deleteAll(RoutineEntity.self, context: context)
        deleteAll(ProgramEntity.self, context: context)
        deleteAll(ExerciseEntity.self, context: context) { $0.isCustom }
        deleteAll(ProgressionRecommendationEntity.self, context: context)
        deleteAll(PersonalRecordEntity.self, context: context)
        deleteAll(UserPreferencesEntity.self, context: context)
        return context.saveOrLog("wipeLocalData")
    }

    private func deleteAll<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext,
        where predicate: ((T) -> Bool)? = nil
    ) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        for item in items {
            if let predicate, !predicate(item) { continue }
            context.delete(item)
        }
    }

    fileprivate func completeSignIn(idToken: String) async {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            userSession.isAuthenticated = true
            userSession.supabaseUserId = session.user.id
            syncEngine.setAuthenticated(true)
            continuation?.resume()
            continuation = nil
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            Task { @MainActor in
                continuation?.resume(throwing: AuthError.missingToken)
                continuation = nil
            }
            return
        }

        Task { @MainActor in
            await completeSignIn(idToken: idToken)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

enum AuthError: LocalizedError {
    case missingToken
    case dataDeletionFailed

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Sign in with Apple did not return an identity token."
        case .dataDeletionFailed: return "We couldn’t fully remove your local data."
        }
    }
}
