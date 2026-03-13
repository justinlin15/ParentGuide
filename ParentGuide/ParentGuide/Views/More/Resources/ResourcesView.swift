//
//  ResourcesView.swift
//  ParentGuide
//

import SwiftUI

// MARK: - Data Models

private struct QuickTip: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let bullets: [String]
}

private struct EmergencyContact: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let icon: String
    let phoneNumber: String?  // nil means no tel: link (e.g. text-only)
}

private struct HelpfulWebsite: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: URL
    let icon: String
}

private struct AgeGuide: Identifiable {
    let id = UUID()
    let ageRange: String
    let label: String
    let icon: String
    let tips: [String]
}

private struct LocalResourceItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let searchQuery: String  // used to build a Google search URL
}

// MARK: - Static Data

private let quickTips: [QuickTip] = [
    QuickTip(
        title: "Screen Time Guidelines",
        icon: "tv",
        color: .eventBlue,
        bullets: [
            "Under 18 months: Avoid screens except video calls",
            "18-24 months: Co-watch high-quality programs only",
            "2-5 years: Limit to 1 hour/day of quality content",
            "6+: Set consistent limits; prioritize sleep & activity",
            "Keep mealtimes and bedrooms screen-free"
        ]
    ),
    QuickTip(
        title: "Healthy Snack Ideas",
        icon: "carrot",
        color: .eventOrange,
        bullets: [
            "Apple slices with peanut butter",
            "Yogurt with berries and granola",
            "Cheese cubes with whole-grain crackers",
            "Veggie sticks with hummus",
            "Frozen banana bites dipped in chocolate"
        ]
    ),
    QuickTip(
        title: "Rainy Day Activities",
        icon: "cloud.rain",
        color: .eventPurple,
        bullets: [
            "Build a blanket fort and read stories",
            "Indoor scavenger hunt with clues",
            "Kitchen science experiments (volcanoes, slime)",
            "Dance party with a family playlist",
            "Arts & crafts with recycled materials"
        ]
    ),
    QuickTip(
        title: "Car Ride Games",
        icon: "car.fill",
        color: .eventGreen,
        bullets: [
            "I Spy with colors or letters",
            "20 Questions (animal, vegetable, mineral)",
            "License plate alphabet game",
            "Story chain: each person adds a sentence",
            "Audiobooks or kid-friendly podcasts"
        ]
    ),
    QuickTip(
        title: "Bedtime Routine Tips",
        icon: "moon.stars",
        color: .brandLavender,
        bullets: [
            "Keep a consistent bedtime, even on weekends",
            "Start winding down 30 min before lights out",
            "Bath, book, and lullaby sequence works well",
            "Dim the lights to signal sleep time",
            "Avoid sugar and screens 1 hour before bed"
        ]
    )
]

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

private let helpfulWebsites: [HelpfulWebsite] = [
    HelpfulWebsite(
        name: "AAP HealthyChildren.org",
        description: "Trusted child health information from pediatricians",
        url: URL(string: "https://www.healthychildren.org")!,
        icon: "heart.text.square"
    ),
    HelpfulWebsite(
        name: "CDC Developmental Milestones",
        description: "Track your child's development by age",
        url: URL(string: "https://www.cdc.gov/ncbddd/actearly/milestones/")!,
        icon: "chart.bar.fill"
    ),
    HelpfulWebsite(
        name: "Common Sense Media",
        description: "Age-appropriate media reviews and ratings",
        url: URL(string: "https://www.commonsensemedia.org")!,
        icon: "film"
    ),
    HelpfulWebsite(
        name: "PBS Kids for Parents",
        description: "Educational activities and parenting advice",
        url: URL(string: "https://www.pbs.org/parents")!,
        icon: "book.fill"
    ),
    HelpfulWebsite(
        name: "NAEYC",
        description: "National Association for the Education of Young Children",
        url: URL(string: "https://www.naeyc.org/our-work/families")!,
        icon: "graduationcap.fill"
    )
]

private let ageGuides: [AgeGuide] = [
    AgeGuide(
        ageRange: "0-3 months",
        label: "Newborn",
        icon: "heart.fill",
        tips: [
            "Tummy time: start with 3-5 minutes, several times a day",
            "Respond to cries promptly to build trust and security",
            "Talk and sing to your baby to encourage language development",
            "Support their head and neck during holding and feeding",
            "Sleep on their back on a firm, flat surface"
        ]
    ),
    AgeGuide(
        ageRange: "3-12 months",
        label: "Infant",
        icon: "figure.and.child.holdinghands",
        tips: [
            "Introduce solid foods around 6 months (iron-rich foods first)",
            "Read board books together daily, even briefly",
            "Offer safe objects to explore different textures",
            "Play peek-a-boo and simple games to build social skills",
            "Childproof your home as mobility increases"
        ]
    ),
    AgeGuide(
        ageRange: "1-3 years",
        label: "Toddler",
        icon: "figure.walk",
        tips: [
            "Offer simple choices to build independence (\"red or blue shirt?\")",
            "Name emotions to help them learn self-regulation",
            "Expect and handle tantrums with patience and consistency",
            "Encourage outdoor play for at least 60 minutes daily",
            "Limit juice; offer water and milk instead"
        ]
    ),
    AgeGuide(
        ageRange: "3-5 years",
        label: "Preschool",
        icon: "paintpalette.fill",
        tips: [
            "Encourage imaginative play and dress-up",
            "Practice letters, numbers, and shapes through games",
            "Teach basic manners: please, thank you, sharing",
            "Set up playdates to develop social skills",
            "Establish a predictable daily routine"
        ]
    ),
    AgeGuide(
        ageRange: "5-12 years",
        label: "School Age",
        icon: "backpack.fill",
        tips: [
            "Create a consistent homework routine and quiet workspace",
            "Encourage at least one extracurricular activity",
            "Have regular family meals and open conversations",
            "Teach online safety and responsible device use",
            "Praise effort and perseverance, not just results"
        ]
    )
]

// MARK: - ResourcesView

struct ResourcesView: View {
    private let metro = MetroService.shared.selectedMetro

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                quickTipsSection
                emergencySection
                websitesSection
                ageGuidesSection
                localResourcesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Resources")
    }

    // MARK: - Quick Tips

    private var quickTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Quick Tips", icon: "lightbulb.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(quickTips) { tip in
                        QuickTipCard(tip: tip)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
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

    // MARK: - Helpful Websites

    private var websitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Helpful Websites", icon: "globe")

            VStack(spacing: 10) {
                ForEach(helpfulWebsites) { site in
                    WebsiteCard(site: site)
                }
            }
        }
    }

    // MARK: - Age-Specific Guides

    private var ageGuidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Age-Specific Guides", icon: "person.3.fill")

            VStack(spacing: 10) {
                ForEach(ageGuides) { guide in
                    AgeGuideCard(guide: guide)
                }
            }
        }
    }

    // MARK: - Local Resources

    private var localResourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Local Resources", icon: "mappin.and.ellipse")

            Text("Based on your metro: \(metro.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(localResourceItems) { item in
                    LocalResourceCard(item: item, metroName: metro.name)
                }
            }
        }
    }

    private var localResourceItems: [LocalResourceItem] {
        [
            LocalResourceItem(
                title: "Public Libraries",
                description: "Find your local library system for free programs and story times",
                icon: "books.vertical.fill",
                searchQuery: "\(metro.name) public library system kids programs"
            ),
            LocalResourceItem(
                title: "Parks & Recreation",
                description: "Youth sports, camps, and community classes near you",
                icon: "leaf.fill",
                searchQuery: "\(metro.name) parks and recreation youth programs"
            ),
            LocalResourceItem(
                title: "Family Resource Centers",
                description: "Local support services for families and children",
                icon: "house.fill",
                searchQuery: "\(metro.name) family resource center"
            ),
            LocalResourceItem(
                title: "Pediatricians Near You",
                description: "Find a board-certified pediatrician in your area",
                icon: "stethoscope",
                searchQuery: "\(metro.name) pediatrician near me"
            )
        ]
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

// MARK: - Quick Tip Card

private struct QuickTipCard: View {
    let tip: QuickTip
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: tip.icon)
                    .font(.title2)
                    .foregroundStyle(tip.color)
                Spacer()
            }

            Text(tip.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tip.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\u{2022}")
                                .foregroundStyle(tip.color)
                                .fontWeight(.bold)
                            Text(bullet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded ? "Show Less" : "Read More")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tip.color)
            }
        }
        .padding(16)
        .frame(width: 200, alignment: .topLeading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
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

// MARK: - Website Card

private struct WebsiteCard: View {
    let site: HelpfulWebsite

    var body: some View {
        Link(destination: site.url) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brandBlue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: site.icon)
                        .font(.title3)
                        .foregroundStyle(Color.brandBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(site.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(site.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.body)
                    .foregroundStyle(Color.brandBlue.opacity(0.6))
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
    }
}

// MARK: - Age Guide Card

private struct AgeGuideCard: View {
    let guide: AgeGuide
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandLavender.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: guide.icon)
                            .font(.title3)
                            .foregroundStyle(Color.brandLavender)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(guide.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text(guide.ageRange)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(guide.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.brandBlue)
                                .padding(.top, 1)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// MARK: - Local Resource Card

private struct LocalResourceCard: View {
    let item: LocalResourceItem
    let metroName: String

    private var searchURL: URL? {
        let query = item.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(query)")
    }

    var body: some View {
        Group {
            if let url = searchURL {
                Link(destination: url) {
                    cardContent
                }
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.eventGreen.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(Color.eventGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(Color.eventGreen.opacity(0.6))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResourcesView()
    }
}
