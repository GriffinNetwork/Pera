import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct PeraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.authState {
                case .loading:
                    SplashView()
                case .authenticated(let userId):
                    MainTabView(userId: userId)
                        .environmentObject(auth)
                case .unauthenticated:
                    AuthView()
                        .environmentObject(auth)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
        }
    }

    private var isAuthenticated: Bool {
        if case .authenticated = auth.authState { return true }
        return false
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Pera")
                .font(.system(size: 40, weight: .bold, design: .rounded))
        }
    }
}
