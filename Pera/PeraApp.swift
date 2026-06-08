import SwiftUI
import FirebaseCore

@main
struct PeraApp: App {
    @State private var auth: AuthService
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"

    init() {
        FirebaseApp.configure()
        _auth = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.authState {
                case .loading:
                    SplashView()
                case .authenticated(let userId):
                    MainTabView(userId: userId)
                        .environment(auth)
                case .unauthenticated:
                    AuthView()
                        .environment(auth)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
            .preferredColorScheme(preferredColorScheme)
        }
    }

    private var isAuthenticated: Bool {
        if case .authenticated = auth.authState { return true }
        return false
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("Pera")
                .font(.system(size: 40, weight: .bold, design: .rounded))
        }
    }
}
