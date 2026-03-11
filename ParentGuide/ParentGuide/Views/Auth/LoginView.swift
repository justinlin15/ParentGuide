//
//  LoginView.swift
//  ParentGuide
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @State private var authService = AuthService.shared
    @State private var isSigningIn = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 60))
                .foregroundStyle(Color.brandBlue)

            VStack(spacing: 8) {
                Text("Parent Guide")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("Sign in to access events, guides,\nand exclusive member content")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                let nonce = authService.prepareNonce()
                request.requestedScopes = [.email, .fullName]
                request.nonce = AuthService.sha256(nonce)
            } onCompletion: { result in
                isSigningIn = true
                Task {
                    await authService.handleAppleSignIn(result: result)
                    isSigningIn = false
                    if authService.isSignedIn {
                        dismiss()
                    }
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .padding(.horizontal, 32)

            // Error message
            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSigningIn {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Signing in...")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
