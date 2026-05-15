import Foundation
import FirebaseAuth

enum AuthState {
    case loading
    case authenticated(String)
    case unauthenticated
}

class AuthService: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: FirebaseAuth.User?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.authState = user.map { .authenticated($0.uid) } ?? .unauthenticated
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    var userId: String? { currentUser?.uid }

    func signIn(email: String, password: String) async {
        await run {
            try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        await run {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let req = result.user.createProfileChangeRequest()
            req.displayName = displayName
            try await req.commitChanges()
        }
    }

    func sendPasswordReset(email: String) async {
        await run {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    private func run(_ block: @escaping () async throws -> Void) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            try await block()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }
}
