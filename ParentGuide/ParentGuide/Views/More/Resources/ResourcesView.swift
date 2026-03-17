//
//  ResourcesView.swift
//  ParentGuide
//

import SwiftUI

// MARK: - Data Models

private struct EmergencyContact: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let icon: String
    let phoneNumber: String?  // nil means no tel: link (e.g. text-only)
}

private struct ResourceLink: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: URL
    let icon: String
}

private struct ResourceCategory: Identifiable {
    let id = UUID()
    let title: String
    let headerIcon: String
    let links: [ResourceLink]
}

// MARK: - Static Data

private let emergencyContacts: [EmergencyContact] = [
    EmergencyContact(
        name: "Poison Control",
        detail: "1-800-222-1222",
        icon: "cross.circle.fill",
        phoneNumber: "18002221222"
    ),
    EmergencyContact(
        name: "National Child Abuse Hotline",
        detail: "1-800-422-4453",
        icon: "hand.raised.fill",
        phoneNumber: "18004224453"
    ),
    EmergencyContact(
        name: "Crisis Text Line",
        detail: "Text HOME to 741741",
        icon: "message.fill",
        phoneNumber: nil
    ),
    EmergencyContact(
        name: "988 Suicide & Crisis Lifeline",
        detail: "Call or text 988",
        icon: "phone.arrow.up.right.fill",
        phoneNumber: "988"
    )
]

private let resourceCategories: [ResourceCategory] = [
    ResourceCategory(
        title: "Health & Development",
        headerIcon: "heart.text.square",
        links: [
            ResourceLink(
                name: "HealthyChildren.org (AAP)",
                description: "Trusted child health information from pediatricians",
                url: URL(string: "https://www.healthychildren.org")!,
                icon: "heart.text.square"
            ),
            ResourceLink(
                name: "CDC Developmental Milestones",
                description: "Track your child's development by age",
                url: URL(string: "https://www.cdc.gov/ncbddd/actearly/milestones/index.html")!,
                icon: "chart.bar.fill"
            ),
            ResourceLink(
                name: "WebMD Children's Health",
                description: "Health topics, symptoms, and wellness for kids",
                url: URL(string: "https://www.webmd.com/children/default.htm")!,
                icon: "stethoscope"
            )
        ]
    ),
    ResourceCategory(
        title: "Activities & Learning",
        headerIcon: "book.fill",
        links: [
            ResourceLink(
                name: "PBS Kids",
                description: "Educational games, videos, and activities for children",
                url: URL(string: "https://pbskids.org")!,
                icon: "play.rectangle.fill"
            ),
            ResourceLink(
                name: "Common Sense Media",
                description: "Age-appropriate media reviews and ratings",
                url: URL(string: "https://www.commonsensemedia.org")!,
                icon: "film"
            ),
            ResourceLink(
                name: "Khan Academy Kids",
                description: "Free educational app for ages 2-8",
                url: URL(string: "https://learn.khanacademy.org/khan-academy-kids/")!,
                icon: "graduationcap.fill"
            ),
            ResourceLink(
                name: "National Geographic Kids",
                description: "Science, animals, and exploration for curious kids",
                url: URL(string: "https://kids.nationalgeographic.com")!,
                icon: "globe.americas.fill"
            )
        ]
    ),
    ResourceCategory(
        title: "Local OC & LA Resources",
        headerIcon: "mappin.and.ellipse",
        links: [
            ResourceLink(
                name: "OC Parks",
                description: "Orange County parks, trails, and outdoor activities",
                url: URL(string: "https://www.ocparks.com")!,
                icon: "leaf.fill"
            ),
            ResourceLink(
                name: "LA County Parks & Recreation",
                description: "Youth sports, camps, and community programs",
                url: URL(string: "https://parks.lacounty.gov")!,
                icon: "figure.run"
            ),
            ResourceLink(
                name: "OC Public Libraries",
                description: "Free story times, programs, and resources",
                url: URL(string: "https://www.ocpl.org")!,
                icon: "books.vertical.fill"
            ),
            ResourceLink(
                name: "LA Public Library",
                description: "Children's programs, homework help, and events",
                url: URL(string: "https://www.lapl.org")!,
                icon: "book.fill"
            ),
            ResourceLink(
                name: "OC Family Resource Centers",
                description: "Local support services for families and children",
                url: URL(string: "https://www.ochealthinfo.com/about-hca/family-health/family-health-community-resources")!,
                icon: "house.fill"
            )
        ]
    ),
    ResourceCategory(
        title: "Parenting Support",
        headerIcon: "figure.and.child.holdinghands",
        links: [
            ResourceLink(
                name: "NAEYC for Families",
                description: "National Association for the Education of Young Children",
                url: URL(string: "https://www.naeyc.org/our-work/families")!,
                icon: "person.3.fill"
            ),
            ResourceLink(
                name: "Postpartum Support International",
                description: "Help for perinatal mood and anxiety disorders",
                url: URL(string: "https://www.postpartum.net")!,
                icon: "heart.circle.fill"
            ),
            ResourceLink(
                name: "La Leche League",
                description: "Breastfeeding support and information",
                url: URL(string: "https://www.llli.org")!,
                icon: "hand.raised.fingers.spread.fill"
            ),
            ResourceLink(
                name: "Zero to Three",
                description: "Early childhood development resources for parents",
                url: URL(string: "https://www.zerotothree.org")!,
                icon: "figure.and.child.holdinghands"
            )
        ]
    )
]

// MARK: - ResourcesView

struct ResourcesView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                // Subtitle header
                Text("Curated resources for OC & LA families")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                emergencySection

                ForEach(resourceCategories) { category in
                    resourceSection(for: category)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Resources")
    }

    // MARK: - Emergency Info

    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Emergency Info", icon: "exclamationmark.triangle.fill")

            VStack(spacing: 0) {
                ForEach(Array(emergencyContacts.enumerated()), id: \.element.id) { index, contact in
                    EmergencyRow(contact: contact)

                    if index < emergencyContacts.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
    }

    // MARK: - Resource Category Section

    private func resourceSection(for category: ResourceCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: category.title, icon: category.headerIcon)

            VStack(spacing: 10) {
                ForEach(category.links) { link in
                    ResourceLinkCard(link: link)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brandBlue)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Emergency Row

private struct EmergencyRow: View {
    let contact: EmergencyContact

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: contact.icon)
                    .font(.body)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(contact.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let phone = contact.phoneNumber,
               let url = URL(string: "tel:\(phone)") {
                Link(destination: url) {
                    Image(systemName: "phone.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Resource Link Card

private struct ResourceLinkCard: View {
    let link: ResourceLink

    var body: some View {
        Link(destination: link.url) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brandBlue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: link.icon)
                        .font(.title3)
                        .foregroundStyle(Color.brandBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(link.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandBlue.opacity(0.6))
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResourcesView()
    }
}
