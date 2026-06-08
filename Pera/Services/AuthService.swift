import Observation
import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AuthState: Equatable {
    case loading
    case authenticated(String)
    case unauthenticated
}

@Observable
@MainActor
class AuthService {
    var authState: AuthState = .loading
    var currentUser: FirebaseAuth.User?
    var errorMessage: String?
    var isLoading = false

    nonisolated(unsafe) private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
                self?.authState = user.map { .authenticated($0.uid) } ?? .unauthenticated
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    var userId: String? { currentUser?.uid }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let req = result.user.createProfileChangeRequest()
            req.displayName = displayName
            try await req.commitChanges()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let user = currentUser, let uid = userId else { return }
            try await FirestoreService().deleteAllUserData(userId: uid)
            try await user.delete()
        } catch let error as NSError where error.domain == AuthErrorDomain
                    && error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            errorMessage = "For security, please sign out and sign back in before deleting your account."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
