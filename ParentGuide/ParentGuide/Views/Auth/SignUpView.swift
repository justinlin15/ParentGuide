//
//  SignUpView.swift
//  ParentGuide
//
//  Sign in with Apple handles both sign-up and sign-in, so this view
//  simply wraps the LoginView for backwards compatibility.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoginView()
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
