//
//  EventDetailView.swift
//  ParentGuide
//

import SwiftUI
import MapKit
import EventKit

struct EventDetailView: View {
    let event: Event
    var onDelete: (() -> Void)?
    var onUpdate: ((Event) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var adminService = AdminService.shared
    @State private var favoritesService = FavoritesService.shared
    @State private var calendarService = CalendarService.shared
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showCalendarSuccess = false
    @State private var showCalendarDenied = false
    @State private var calendarErrorMessage: String?
    @State private var isAddingToCalendar = false

    private var isFavorite: Bool {
        favoritesService.isFavorite(event.id)
    }

    private var shareText: String {
        var text = "\(event.title)\n\(event.formattedDate)"
        if !event.isAllDay {
            text += " \(event.formattedTime)"
        }
        if let location = event.locationName {
            text += "\n\(location)"
        }
        text += "\n\(event.city)"
        if let url = event.externalURL {
            text += "\n\(url)"
        }
        return text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                if let imageURL = event.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImagePhase(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 220)
                                .clipped()
                                .overlay(alignment: .bottomLeading) {
                                    categoryBadge
                                }
                        default:
                            heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Title row with share + favorite
                    HStack(alignment: .top) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                favoritesService.toggleFavorite(for: event)
                            }
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(isFavorite ? Color.brandBlue : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Date and Location row
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.brandBlue)
                            Text(event.formattedDate)
                                .font(.subheadline)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(event.category.color)
                            Text(event.city)
                                .font(.subheadline)
                        }
                    }
                    .foregroundStyle(.secondary)

                    // Time
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundStyle(Color.brandBlue)
                        Text(event.formattedTime)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)

                    // Quick info pills (category, price, age)
                    FlowLayout(spacing: 8) {
                        Label(event.category.rawValue, systemImage: event.category.iconName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(event.category.color)
                            .clipShape(Capsule())

                        if let tierDisplay = event.priceTierDisplay {
                            Label(tierDisplay, systemImage: event.isFree ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(priceTierBadgeColor)
                                .clipShape(Capsule())
                        }

                        if let ageRange = event.ageRange, !ageRange.isEmpty {
                            Label(ageRange, systemImage: "figure.and.child.holdinghands")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.purple.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }

                    // Actual price text (if available and not just "Free")
                    if let price = event.price, !price.isEmpty, !event.isFree {
                        HStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(Color.brandBlue)
                            Text("Price: \(price)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    Divider()

                    // About section
                    if !event.eventDescription.isEmpty {
                        Text("About")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(event.eventDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Location section
                    if event.hasLocation {
                        Divider()

                        Text("Location")
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let name = event.locationName {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let address = event.address {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let lat = event.latitude, let lon = event.longitude {
                            let position = MapCameraPosition.region(
                                MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                            )

                            Map(initialPosition: position) {
                                Marker(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                    .tint(event.category.color)
                            }
                            .frame(height: 200)
                            .cornerRadius(12)

                            Button {
                                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                                mapItem.name = event.locationName ?? event.title
                                mapItem.openInMaps()
                            } label: {
                                Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.brandBlue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }

                    // Contact details
                    if event.phone != nil || event.contactEmail != nil || event.websiteURL != nil {
                        Divider()

                        Text("Contact")
                            .font(.title3)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 10) {
                            if let phone = event.phone {
                                Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                                    Label(phone, systemImage: "phone.fill")
                                        .font(.subheadline)
                                }
                            }

                            if let email = event.contactEmail {
                                Link(destination: URL(string: "mailto:\(email)")!) {
                                    Label(email, systemImage: "envelope.fill")
                                        .font(.subheadline)
                                }
                            }

                            if let webURL = event.websiteURL, let url = URL(string: webURL) {
                                Link(destination: url) {
                                    Label("Visit Website", systemImage: "globe")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Action buttons
                    Divider()

                    VStack(spacing: 12) {
                        // Add to Calendar button
                        Button {
                            addToCalendar()
                        } label: {
                            Label(
                                isAddingToCalendar ? "Adding..." : "Add to Calendar",
                                systemImage: "calendar.badge.plus"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brandBlue)
                            .foregroundStyle(.white)
                            .font(.headline)
                            .cornerRadius(12)
                        }
                        .disabled(isAddingToCalendar)

                        // More info — prefer original venue website over aggregator blog
                        if let urlString = event.websiteURL ?? event.externalURL,
                           let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label("More Information", systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemGray6))
                                    .foregroundStyle(.primary)
                                    .font(.headline)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if adminService.isAdmin {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EventFormView(editingEvent: event) { updatedEvent in
                onUpdate?(updatedEvent)
            }
        }
        .alert("Delete Event", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete \"\(event.title)\"? This cannot be undone.")
        }
        .alert("Added to Calendar!", isPresented: $showCalendarSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\"\(event.title)\" has been added to your calendar with a 1-hour reminder.")
        }
        .alert("Calendar Access Required", isPresented: $showCalendarDenied) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow calendar access in Settings to add events to your calendar.")
        }
        .alert("Calendar Error", isPresented: .init(
            get: { calendarErrorMessage != nil },
            set: { if !$0 { calendarErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(calendarErrorMessage ?? "An error occurred.")
        }
    }

    private func addToCalendar() {
        isAddingToCalendar = true
        Task {
            let result = await calendarService.addToCalendar(event)
            await MainActor.run {
                isAddingToCalendar = false
                switch result {
                case .success:
                    showCalendarSuccess = true
                case .denied:
                    showCalendarDenied = true
                case .error(let message):
                    calendarErrorMessage = message
                }
            }
        }
    }

    private func deleteEvent() {
        isDeleting = true
        Task {
            do {
                try await EventService.shared.deleteEvent(id: event.id)
                await MainActor.run {
                    onDelete?()
                    dismiss()
                }
            } catch {
                print("[EventDetailView] Delete failed: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }

    private var categoryBadge: some View {
        Label(event.category.rawValue, systemImage: event.category.iconName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(event.category.color.opacity(0.85))
            .clipShape(Capsule())
            .padding(12)
    }

    private var priceTierBadgeColor: Color {
        switch event.priceTier {
        case 0:  return .green
        case 1:  return .green.opacity(0.8)
        case 2:  return .blue.opacity(0.8)
        case 3:  return .orange
        case 4:  return .red.opacity(0.8)
        case 5:  return .red
        default: return .gray
        }
    }

    private var heroPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(event.category.color.opacity(0.15))
            VStack(spacing: 8) {
                Image(systemName: event.category.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(event.category.color)
                Text(event.category.rawValue)
                    .font(.headline)
                    .foregroundStyle(event.category.color)
            }
        }
        .frame(height: 220)
        .overlay(alignment: .bottomLeading) {
            categoryBadge
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: PreviewData.sampleEvents[0])
    }
}
