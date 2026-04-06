import SwiftUI
import AuthenticationServices

/// Sign-in screen. Shows when the user is not authenticated.
struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon / logo area
                VStack(spacing: 12) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("THC")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Homie Cup")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .kerning(2)
                }

                Spacer()

                // Sign-in section
                VStack(spacing: 16) {
                    signInButton
                        .disabled(isSigningIn)

                    Text("Sign in with your THC Google account.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
            }
        }
    }

    // MARK: - Sign-in Button

    private var signInButton: some View {
        Button {
            triggerSignIn()
        } label: {
            HStack(spacing: 12) {
                if isSigningIn {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.primary)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                }
                Text(isSigningIn ? "Signing in…" : "Sign in with Google")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.tertiarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Actions

    private func triggerSignIn() {
        guard !isSigningIn else { return }
        isSigningIn = true

        Task {
            defer { isSigningIn = false }
            // Obtain the ASPresentationAnchor from the current key window.
            let anchor = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
            await authManager.signIn(presenting: anchor)
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager(supabase: PreviewSupabaseClient()))
}
