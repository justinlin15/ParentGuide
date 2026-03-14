//
//  PrivacyPolicyView.swift
//  ParentGuide
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Last updated: March 12, 2026")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                policySection(
                    title: "Introduction",
                    body: "Parent Guide (\"we\", \"our\", or \"us\") operates the Parent Guide mobile application. This page informs you of our policies regarding the collection, use, and disclosure of personal information when you use our app. We are committed to protecting the privacy of families who use our services."
                )

                policySection(
                    title: "Information We Collect",
                    items: [
                        "Account Information: When you create an account using Sign in with Apple, we receive your name and email address (or a private relay email if you choose to hide your email).",
                        "Profile Information: Information you voluntarily provide such as your children's names and birthdays, interest preferences, and metro area selection.",
                        "Location Data: With your permission, we access your device location to show nearby events and auto-detect your metro area. Location data is processed on-device and is not stored on our servers.",
                        "Favorites & Preferences: Your favorited events, notification preferences, and filter settings are stored locally on your device and synced via iCloud to your personal Apple account.",
                        "Usage Data: We may collect anonymous, aggregated usage data to improve app performance and features. This data cannot be used to identify you personally.",
                    ]
                )

                policySection(
                    title: "How We Use Your Information",
                    items: [
                        "To personalize your experience by showing events relevant to your location and interests.",
                        "To send push notifications about events you've favorited or that match your preferences (only if you opt in).",
                        "To sync your profile, favorites, and preferences across your Apple devices via iCloud.",
                        "To improve and maintain our app's functionality and performance.",
                    ]
                )

                policySection(
                    title: "Data Storage & Security",
                    body: "Your data is stored using Apple's CloudKit and iCloud infrastructure, which means it is encrypted in transit and at rest. Your personal data is stored in your private iCloud database and is only accessible to you. We do not have access to your iCloud data. Local preferences are stored on your device using standard iOS secure storage."
                )

                policySection(
                    title: "Third-Party Services",
                    body: "We aggregate event information from third-party sources including Ticketmaster, SeatGeek, and various family event websites. When you tap an external link to purchase tickets or visit an event page, you will be directed to that third party's website or app, which is governed by their own privacy policy. We do not share your personal information with these third parties."
                )

                policySection(
                    title: "Children's Privacy",
                    body: "Parent Guide is designed for use by parents and caregivers. We do not knowingly collect personal information directly from children under 13. Children's names and birthdays that parents enter in their profile are stored in the parent's private iCloud account and are used solely to provide age-appropriate event recommendations."
                )

                policySection(
                    title: "Your Rights & Choices",
                    items: [
                        "Location Access: You can enable or disable location services for Parent Guide at any time in your device Settings.",
                        "Notifications: You can manage notification preferences within the app or disable them entirely in device Settings.",
                        "Account Deletion: You can delete your account and all associated data by contacting us at support@parentguide.com. Your iCloud data can be managed through your Apple ID settings.",
                        "Data Portability: Since your data is stored in your personal iCloud account, it is already under your control.",
                    ]
                )

                policySection(
                    title: "Data Retention",
                    body: "We retain your account information for as long as your account is active. If you delete your account, we will remove your data from our systems within 30 days. Anonymous, aggregated usage data may be retained indefinitely for analytics purposes."
                )

                policySection(
                    title: "Changes to This Policy",
                    body: "We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy in the app and updating the \"Last updated\" date. You are advised to review this page periodically for any changes."
                )

                policySection(
                    title: "Contact Us",
                    body: "If you have any questions about this Privacy Policy, please contact us at support@parentguide.com."
                )

                // Footer
                VStack(spacing: 8) {
                    Divider()
                    Text("Parent Guide")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Built by parents, for parents")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section Builders

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    private func policySection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\u{2022}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
