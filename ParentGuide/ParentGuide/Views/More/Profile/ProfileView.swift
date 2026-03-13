//
//  ProfileView.swift
//  ParentGuide
//

import SwiftUI

// MARK: - ChildInfo Model

struct ChildInfo: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var birthday: Date

    init(id: UUID = UUID(), name: String = "", birthday: Date = Date()) {
        self.id = id
        self.name = name
        self.birthday = birthday
    }

    var age: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: birthday, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0

        if years < 1 {
            return "\(months) mo"
        } else if years == 1 && months > 0 {
            return "1 yr, \(months) mo"
        } else {
            return "\(years) yr\(years == 1 ? "" : "s")"
        }
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    @State private var authService = AuthService.shared
    @State private var metroService = MetroService.shared
    @State private var favoritesService = FavoritesService.shared

    // MARK: - Children (persisted as JSON in @AppStorage)

    @AppStorage("profile_children_json") private var childrenJSON: String = "[]"
    @State private var children: [ChildInfo] = []
    @State private var isAddingChild = false

    // MARK: - Interests (persisted in @AppStorage)

    @AppStorage("interest_storytime") private var interestStorytime = false
    @AppStorage("interest_farmersMarket") private var interestFarmersMarket = false
    @AppStorage("interest_freeMovie") private var interestFreeMovie = false
    @AppStorage("interest_toddlerActivity") private var interestToddlerActivity = false
    @AppStorage("interest_craft") private var interestCraft = false
    @AppStorage("interest_music") private var interestMusic = false
    @AppStorage("interest_museum") private var interestMuseum = false
    @AppStorage("interest_outdoorAdventure") private var interestOutdoorAdventure = false
    @AppStorage("interest_food") private var interestFood = false
    @AppStorage("interest_sports") private var interestSports = false
    @AppStorage("interest_education") private var interestEducation = false
    @AppStorage("interest_festival") private var interestFestival = false
    @AppStorage("interest_seasonal") private var interestSeasonal = false

    // MARK: - Notification Preferences (persisted in @AppStorage)

    @AppStorage("notify_newEvents") private var notifyNewEvents = true
    @AppStorage("notify_matchingInterests") private var notifyMatchingInterests = true
    @AppStorage("notify_weeklyDigest") private var notifyWeeklyDigest = false

    var body: some View {
        Form {
            // MARK: - Profile Header
            profileHeaderSection

            // MARK: - My Family
            myFamilySection

            // MARK: - My Interests
            myInterestsSection

            // MARK: - My Location
            myLocationSection

            // MARK: - Notification Preferences
            notificationPreferencesSection

            // MARK: - Stats
            statsSection
        }
        .navigationTitle("Profile")
        .onAppear {
            loadChildren()
        }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.brandBlue)

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
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - My Family Section

    private var myFamilySection: some View {
        Section {
            if children.isEmpty && !isAddingChild {
                Text("Add your children to get personalized event recommendations based on their ages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(children) { child in
                HStack(spacing: 12) {
                    Image(systemName: "figure.child")
                        .foregroundStyle(Color.brandBlue)
                        .font(.title3)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name.isEmpty ? "Unnamed" : child.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Age: \(child.age)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(child.birthday.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: removeChild)

            if isAddingChild {
                addChildForm
            }

            Button {
                if isAddingChild {
                    // Already showing form, do nothing extra
                } else {
                    withAnimation {
                        isAddingChild = true
                    }
                }
            } label: {
                Label("Add Child", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.brandBlue)
            }
            .disabled(isAddingChild)
        } header: {
            Label("My Family", systemImage: "figure.2.and.child.holdinghands")
        }
    }

    // MARK: - Add Child Inline Form

    @State private var newChildName: String = ""
    @State private var newChildBirthday: Date = Date()

    private var addChildForm: some View {
        VStack(spacing: 12) {
            TextField("Child's Name", text: $newChildName)
                .textContentType(.name)

            DatePicker(
                "Birthday",
                selection: $newChildBirthday,
                in: ...Date(),
                displayedComponents: .date
            )

            HStack {
                Button("Cancel") {
                    withAnimation {
                        newChildName = ""
                        newChildBirthday = Date()
                        isAddingChild = false
                    }
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button("Add") {
                    let child = ChildInfo(
                        name: newChildName.trimmingCharacters(in: .whitespacesAndNewlines),
                        birthday: newChildBirthday
                    )
                    withAnimation {
                        children.append(child)
                        saveChildren()
                        newChildName = ""
                        newChildBirthday = Date()
                        isAddingChild = false
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.brandBlue)
                .disabled(newChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - My Interests Section

    private var myInterestsSection: some View {
        Section {
            interestToggle("Storytime", icon: EventCategory.storytime.iconName, color: EventCategory.storytime.color, isOn: $interestStorytime)
            interestToggle("Farmers Markets", icon: EventCategory.farmersMarket.iconName, color: EventCategory.farmersMarket.color, isOn: $interestFarmersMarket)
            interestToggle("Free Movies", icon: EventCategory.freeMovie.iconName, color: EventCategory.freeMovie.color, isOn: $interestFreeMovie)
            interestToggle("Toddler Activities", icon: EventCategory.toddlerActivity.iconName, color: EventCategory.toddlerActivity.color, isOn: $interestToddlerActivity)
            interestToggle("Crafts", icon: EventCategory.craft.iconName, color: EventCategory.craft.color, isOn: $interestCraft)
            interestToggle("Music", icon: EventCategory.music.iconName, color: EventCategory.music.color, isOn: $interestMusic)
            interestToggle("Museums", icon: EventCategory.museum.iconName, color: EventCategory.museum.color, isOn: $interestMuseum)
            interestToggle("Outdoor Adventures", icon: EventCategory.outdoorAdventure.iconName, color: EventCategory.outdoorAdventure.color, isOn: $interestOutdoorAdventure)
            interestToggle("Food & Dining", icon: EventCategory.food.iconName, color: EventCategory.food.color, isOn: $interestFood)
            interestToggle("Sports", icon: EventCategory.sports.iconName, color: EventCategory.sports.color, isOn: $interestSports)
            interestToggle("Education", icon: EventCategory.education.iconName, color: EventCategory.education.color, isOn: $interestEducation)
            interestToggle("Festivals", icon: EventCategory.festival.iconName, color: EventCategory.festival.color, isOn: $interestFestival)
            interestToggle("Seasonal", icon: EventCategory.seasonal.iconName, color: EventCategory.seasonal.color, isOn: $interestSeasonal)
        } header: {
            Label("My Interests", systemImage: "heart.fill")
        } footer: {
            Text("Select categories to get personalized recommendations.")
        }
    }

    private func interestToggle(_ title: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .tint(Color.brandBlue)
    }

    // MARK: - My Location Section

    private var myLocationSection: some View {
        Section {
            NavigationLink {
                LocationSettingsView()
            } label: {
                HStack {
                    Label {
                        Text("Metro Area")
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Color.brandBlue)
                    }

                    Spacer()

                    Text(metroService.selectedMetro.name)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        } header: {
            Label("My Location", systemImage: "location.fill")
        }
    }

    // MARK: - Notification Preferences Section

    private var notificationPreferencesSection: some View {
        Section {
            Toggle(isOn: $notifyNewEvents) {
                Label {
                    Text("New Events in My Area")
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }
            .tint(Color.brandBlue)

            Toggle(isOn: $notifyMatchingInterests) {
                Label {
                    Text("Events Matching My Interests")
                } icon: {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }
            .tint(Color.brandBlue)

            Toggle(isOn: $notifyWeeklyDigest) {
                Label {
                    Text("Weekly Event Digest")
                } icon: {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }
            .tint(Color.brandBlue)
        } header: {
            Label("Notifications", systemImage: "bell.fill")
        } footer: {
            Text("Control which notifications you receive about family events.")
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        Section {
            HStack {
                Label {
                    Text("Events Favorited")
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
                Spacer()
                Text("\(favoritesService.count)")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandBlue)
            }

            if let user = authService.currentUser {
                HStack {
                    Label {
                        Text("Member Since")
                    } icon: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color.brandBlue)
                    }
                    Spacer()
                    Text(user.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label {
                    Text("Children")
                } icon: {
                    Image(systemName: "figure.child")
                        .foregroundStyle(Color.brandBlue)
                }
                Spacer()
                Text("\(children.count)")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandBlue)
            }
        } header: {
            Label("Stats", systemImage: "chart.bar.fill")
        }
    }

    // MARK: - Children Persistence

    private func loadChildren() {
        guard let data = childrenJSON.data(using: .utf8) else { return }
        do {
            children = try JSONDecoder().decode([ChildInfo].self, from: data)
        } catch {
            print("[ProfileView] Failed to decode children: \(error)")
            children = []
        }
    }

    private func saveChildren() {
        do {
            let data = try JSONEncoder().encode(children)
            childrenJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("[ProfileView] Failed to encode children: \(error)")
        }
    }

    private func removeChild(at offsets: IndexSet) {
        children.remove(atOffsets: offsets)
        saveChildren()
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
