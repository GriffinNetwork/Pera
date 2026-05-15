import SwiftUI

struct AuthView: View {
    @State private var showLogin = true

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("Pera")
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("Your personal budget, simplified.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if showLogin {
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)))
                } else {
                    SignUpView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)))
                }

                Spacer().frame(height: 32)

                Button {
                    withAnimation(.spring(response: 0.4)) { showLogin.toggle() }
                } label: {
                    if showLogin {
                        Text("Don't have an account? ") + Text("Sign Up").bold().foregroundColor(.accentColor)
                    } else {
                        Text("Already have an account? ") + Text("Log In").bold().foregroundColor(.accentColor)
                    }
                }
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }
}
