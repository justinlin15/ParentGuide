//
//  ProfileView.swift
//  ParentGuide
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Avatar placeholder
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.brandBlue)
                .padding(.top, 40)

            Text("kailin84")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Member since 2024")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
