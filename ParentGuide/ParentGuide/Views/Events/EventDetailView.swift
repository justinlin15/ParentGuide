//
//  EventDetailView.swift
//  ParentGuide
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: Event
    var onDelete: (() -> Void)?
    var onUpdate: ((Event) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var adminService = AdminService.shared
    @State private var favoritesService = FavoritesService.shared
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    private var isFavorite: Bool {
        favoritesService.isFavorite(event.id)
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
                    // Title row with favorite
                    HStack(alignment: .top) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                favoritesService.toggleFavorite(event.id)
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

                    // Category tag
                    Label(event.category.rawValue, systemImage: event.category.iconName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(event.category.color)
                        .clipShape(Capsule())

                    Divider()

                    // About section
                    Text("About")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(event.eventDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)

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

                    // External link
                    if let urlString = event.externalURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("More Information", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
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
