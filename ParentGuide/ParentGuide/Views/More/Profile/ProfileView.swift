//
//  ProfileView.swift
//  ParentGuide
//

import SwiftUI

struct ProfileView: View {
    @State private var authService = AuthService.shared

    var body: some View {
        VStack(spacing: 20) {
            // Avatar placeholder
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.brandBlue)
                .padding(.top, 40)

            if let user = authService.currentUser {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Member since \(user.createdAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Parent")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
