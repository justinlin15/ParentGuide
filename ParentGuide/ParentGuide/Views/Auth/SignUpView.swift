//
//  SignUpView.swift
//  ParentGuide
//

import SwiftUI

struct SignUpView: View {
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)

                Button {
                    // TODO: Implement sign up
                } label: {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandBlue)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SignUpView()
}
