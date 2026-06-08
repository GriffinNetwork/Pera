import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) var auth

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool { password == confirmPassword }
    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && passwordsMatch && !auth.isLoading
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                TextField("Full Name", text: $name)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SecureField("Password (min 6 chars)", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords don't match.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let err = auth.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.signUp(email: email, password: password, displayName: name) }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Account").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSubmit ? Color.accentColor : Color.accentColor.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSubmit)
        }
    }
}
