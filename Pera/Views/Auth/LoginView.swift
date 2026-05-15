import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var showResetAlert = false
    @State private var resetSent = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let err = auth.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.signIn(email: email, password: password) }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Log In").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

            Button("Forgot password?") { showResetAlert = true }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .alert("Reset Password", isPresented: $showResetAlert) {
            TextField("Email", text: $email)
            Button("Send Reset Link") {
                Task {
                    await auth.sendPasswordReset(email: email)
                    resetSent = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Reset link sent!", isPresented: $resetSent) {
            Button("OK", role: .cancel) {}
        }
    }
}
