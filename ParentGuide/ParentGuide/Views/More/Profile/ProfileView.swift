//
//  ProfileView.swift
//  ParentGuide
//

import SwiftUI
import PhotosUI

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

// MARK: - ProfileView (Combined Profile & Settings)

struct ProfileView: View {
    @State private var authService = AuthService.shared
    @State private var metroService = MetroService.shared
    @State private var favoritesService = FavoritesService.shared

    // MARK: - Children (persisted as JSON in @AppStorage)

    @AppStorage("profile_children_json") private var childrenJSON: String = "[]"
    @State private var children: [ChildInfo] = []
    @State private var isAddingChild = false

    // MARK: - Profile Picture
    @State private var profileImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    // MARK: - Editable Display Name
    @State private var isEditingName = false
    @State private var editedName: String = ""

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

    @AppStorage("notify_pushEnabled") private var pushNotificationsEnabled = true
    @AppStorage("notify_newEvents") private var notifyNewEvents = true
    @AppStorage("notify_matchingInterests") private var notifyMatchingInterests = true
    @AppStorage("notify_weeklyDigest") private var notifyWeeklyDigest = false
    @AppStorage("addToCalendarOnFavorite") private var addToCalendarOnFavorite = false

    // MARK: - App Preferences (from AccountSettingsView)

    @AppStorage("defaultEventView") private var defaultEventView: String = "Week"
    @AppStorage("defaultSearchRadius") private var defaultSearchRadius: String = "Any"
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"

    var body: some View {
        Form {
            profileHeaderSection
            myFamilySection
            myInterestsSection
            appSettingsSection
            notificationsSection
            supportSection
            aboutSection
            accountSection
        }
        .navigationTitle("Profile & Settings")
        .onAppear {
            loadChildren()
            loadProfileImage()
        }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                // Profile picture with photo picker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.brandBlue, lineWidth: 2))
                            .overlay(alignment: .bottomTrailing) {
                                cameraEditBadge
                            }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.brandBlue)
                            .overlay(alignment: .bottomTrailing) {
                                cameraEditBadge
                            }
                    }
                }
                .onChange(of: selectedPhotoItem) {
                    Task { await loadSelectedPhoto() }
                }

                if let user = authService.currentUser {
                    // Editable display name
                    if isEditingName {
                        HStack(spacing: 8) {
                            TextField("Your name", text: $editedName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)

                            Button("Save") {
                                let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    KeychainService.save(key: KeychainService.appleDisplayName, value: trimmed)
                                    Task { await authService.refreshProfile() }
                                }
                                isEditingName = false
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandBlue)
                        }
                    } else {
                        Button {
                            editedName = user.displayName
                            isEditingName = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !user.email.isEmpty {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Member since \(user.createdAt.formatted(.dateTime.month(.wide).year()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Guest")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Sign in to sync your profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var cameraEditBadge: some View {
        Image(systemName: "camera.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color.brandBlue)
            .background(Circle().fill(.white).frame(width: 22, height: 22))
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
                if !isAddingChild {
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

    // MARK: - App Settings Section (merged from AccountSettingsView)

    private var appSettingsSection: some View {
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
                        .lineLimit(1)
                }
            }

            Picker(selection: $defaultEventView) {
                Text("Week").tag("Week")
                Text("Day").tag("Day")
                Text("Month").tag("Month")
                Text("Map").tag("Map")
            } label: {
                Label {
                    Text("Default View")
                } icon: {
                    Image(systemName: "rectangle.split.3x1")
                        .foregroundStyle(Color.brandBlue)
                }
            }

            Picker(selection: $defaultSearchRadius) {
                Text("5 mi").tag("5")
                Text("10 mi").tag("10")
                Text("25 mi").tag("25")
                Text("50 mi").tag("50")
                Text("Any").tag("Any")
            } label: {
                Label {
                    Text("Default Radius")
                } icon: {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(Color.brandBlue)
                }
            }

            Picker(selection: $appearanceMode) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            } label: {
                Label {
                    Text("Appearance")
                } icon: {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(Color.brandBlue)
                }
            }
        } header: {
            Label("App Settings", systemImage: "gearshape.fill")
        } footer: {
            Text("These defaults are applied when you open the Events tab.")
        }
    }

    // MARK: - Notifications Section (combined)

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $pushNotificationsEnabled) {
                Label {
                    Text("Push Notifications")
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }
            .tint(Color.brandBlue)

            Toggle(isOn: $notifyNewEvents) {
                Label {
                    Text("New Events in My Area")
                } icon: {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }
            .tint(Color.brandBlue)

            Toggle(isOn: $notifyMatchingInterests) {
                Label {
                    Text("Events Matching Interests")
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

            Toggle(isOn: $addToCalendarOnFavorite) {
                Label {
                    Text("Add to Calendar on Favorite")
                } icon: {
                    Image(systemName: "calendar.badge.plus")
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

    // MARK: - Support Section (from AccountSettingsView)

    private var supportSection: some View {
        Section("Support") {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label {
                    Text("Privacy Policy")
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }

            Link(destination: URL(string: "mailto:support@parentguide.com")!) {
                Label {
                    Text("Contact Us")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }

            Link(destination: URL(string: "https://apps.apple.com/app/parent-guide/id0000000000")!) {
                Label {
                    Text("Rate the App")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.brandBlue)
                }
            }
        }
    }

    // MARK: - About Section (stats + version)

    private var aboutSection: some View {
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

            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Parent Guide")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Version \(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Built by parents, for parents")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            Label("About", systemImage: "info.circle.fill")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            if authService.isSignedIn {
                Button(role: .destructive) {
                    authService.signOut()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                NavigationLink(destination: LoginView()) {
                    Label("Sign In", systemImage: "person.circle")
                        .foregroundStyle(Color.brandBlue)
                }
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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

    // MARK: - Profile Picture Persistence

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    profileImage = uiImage
                    saveProfileImage(data: data)
                }
            }
        } catch {
            print("[ProfileView] Failed to load photo: \(error)")
        }
    }

    private func saveProfileImage(data: Data) {
        let url = Self.profileImageURL
        try? data.write(to: url)
    }

    private func loadProfileImage() {
        let url = Self.profileImageURL
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            profileImage = image
        }
    }

    private static var profileImageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("profile_photo.jpg")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
