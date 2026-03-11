//
//  LoginView.swift
//  ParentGuide
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo placeholder
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 60))
                .foregroundStyle(Color.brandBlue)

            Text("Parent Guide")
                .font(.title)
                .fontWeight(.bold)

            // Email field
            VStack(spacing: 12) {
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 32)

            // Forgot password
            Button("Forgot password?") {}
                .font(.caption)
                .foregroundStyle(.secondary)

            // Sign in button
            Button {
                // TODO: Implement email sign in
            } label: {
                Text("Sign in")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandBlue)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 32)

            // Divider
            HStack {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                Text("or sign in with")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    print("Sign in with Apple failed: \(error)")
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .padding(.horizontal, 32)

            // Sign up link
            HStack {
                Text("Don't have an account?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Sign up") {
                    showSignUp = true
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }

            Spacer()
        }
        .navigationTitle("Log In")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
