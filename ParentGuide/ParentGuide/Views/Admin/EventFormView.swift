//
//  EventFormView.swift
//  ParentGuide
//

import SwiftUI

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss

    let editingEvent: Event?
    var onSave: ((Event) -> Void)?

    @State private var title = ""
    @State private var eventDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var hasEndDate = false
    @State private var isAllDay = false
    @State private var category: EventCategory = .other
    @State private var city = ""
    @State private var address = ""
    @State private var locationName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var imageURL = ""
    @State private var externalURL = ""
    @State private var isFeatured = false
    @State private var isRecurring = false
    @State private var tagsText = ""
    @State private var metro = "los-angeles"

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { editingEvent != nil }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Event Details") {
                    TextField("Title", text: $title)

                    TextField("Description", text: $eventDescription, axis: .vertical)
                        .lineLimit(3...8)

                    Picker("Category", selection: $category) {
                        ForEach(EventCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }
                }

                // Date & Time
                Section("Date & Time") {
                    Toggle("All Day", isOn: $isAllDay)

                    if isAllDay {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker("Start", selection: $startDate)
                    }

                    Toggle("Has End Time", isOn: $hasEndDate)

                    if hasEndDate && !isAllDay {
                        DatePicker("End", selection: $endDate)
                    }

                    Toggle("Recurring", isOn: $isRecurring)
                }

                // Location
                Section("Location") {
                    TextField("City", text: $city)

                    TextField("Venue Name", text: $locationName)

                    TextField("Address", text: $address)

                    HStack {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Metro Area", selection: $metro) {
                        ForEach(AppConstants.metroAreas, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                }

                // Media & Links
                Section("Media & Links") {
                    TextField("Image URL", text: $imageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)

                    TextField("External URL", text: $externalURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                // Tags & Promotion
                Section("Tags & Options") {
                    TextField("Tags (comma-separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)

                    Toggle("Featured", isOn: $isFeatured)
                }

                // Error display
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveEvent()
                    }
                    .disabled(!isFormValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let event = editingEvent {
                    populateForm(from: event)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func populateForm(from event: Event) {
        title = event.title
        eventDescription = event.eventDescription
        startDate = event.startDate
        if let end = event.endDate {
            endDate = end
            hasEndDate = true
        }
        isAllDay = event.isAllDay
        category = event.category
        city = event.city
        address = event.address ?? ""
        locationName = event.locationName ?? ""
        if let lat = event.latitude {
            latitude = String(lat)
        }
        if let lon = event.longitude {
            longitude = String(lon)
        }
        imageURL = event.imageURL ?? ""
        externalURL = event.externalURL ?? ""
        isFeatured = event.isFeatured
        isRecurring = event.isRecurring
        tagsText = event.tags.joined(separator: ", ")
        metro = event.metro ?? "los-angeles"
    }

    private func saveEvent() {
        isSaving = true
        errorMessage = nil

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let lat = Double(latitude)
        let lon = Double(longitude)

        let event = Event(
            id: editingEvent?.id ?? "admin-\(UUID().uuidString)",
            title: title.trimmingCharacters(in: .whitespaces),
            eventDescription: eventDescription.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            isAllDay: isAllDay,
            category: category,
            city: city.trimmingCharacters(in: .whitespaces),
            address: address.isEmpty ? nil : address,
            latitude: lat,
            longitude: lon,
            locationName: locationName.isEmpty ? nil : locationName,
            imageURL: imageURL.isEmpty ? nil : imageURL,
            externalURL: externalURL.isEmpty ? nil : externalURL,
            isFeatured: isFeatured,
            isRecurring: isRecurring,
            tags: tags,
            metro: metro,
            source: "admin",
            manuallyEdited: true,
            createdAt: editingEvent?.createdAt ?? Date(),
            modifiedAt: Date()
        )

        Task {
            do {
                if isEditing {
                    let saved = try await EventService.shared.updateEvent(event)
                    await MainActor.run {
                        onSave?(saved)
                        dismiss()
                    }
                } else {
                    let saved = try await EventService.shared.createEvent(event)
                    await MainActor.run {
                        onSave?(saved)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview("Create") {
    EventFormView(editingEvent: nil)
}

#Preview("Edit") {
    EventFormView(editingEvent: PreviewData.sampleEvents[0])
}
