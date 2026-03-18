//
//  SuggestEventView.swift
//  ParentGuide
//

import MapKit
import SwiftUI

struct SuggestEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var metroService = MetroService.shared
    @State private var authService = AuthService.shared

    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var city = ""
    @State private var locationName = ""
    @State private var address = ""
    @State private var externalURL = ""
    @State private var selectedCategory: EventCategory = .other

    @State private var isSubmitting = false
    @State private var isSubmitted = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        if isSubmitted {
            // Success state — replaces entire form
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Suggestion Submitted!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Thank you for helping make Parent Guide better! Our team will review your event and add it if approved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                Button {
                    // Reset form for another suggestion
                    resetForm()
                } label: {
                    Text("Suggest Another Event")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandBlue)
                }

                Spacer()
            }
            .navigationTitle("Suggest an Event")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            // Form state
            Form {
                Section("Event Details") {
                    TextField("Event Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(EventCategory.allCases.filter { $0 != .subscriberMeetup }) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section("Date & Time") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Location") {
                    LocationSearchField(
                        placeholder: "Search for a place or address",
                        text: $locationName
                    ) { completion in
                        // Resolve the selected location to get full details
                        Task { @MainActor in
                            if let mapItem = await completion.resolve() {
                                let placemark = mapItem.placemark
                                self.locationName = mapItem.name ?? completion.title
                                self.city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
                                self.address = [
                                    placemark.subThoroughfare,
                                    placemark.thoroughfare
                                ].compactMap { $0 }.joined(separator: " ")
                            }
                        }
                    }

                    if !city.isEmpty {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.brandBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(locationName.isEmpty ? city : locationName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !address.isEmpty {
                                    Text("\(address), \(city)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(city)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Link") {
                    TextField("Event Website URL", text: $externalURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section {
                    Button {
                        submitSuggestion()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                Text("Submitting...")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            } else {
                                Text("Submit Suggestion")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(isValid && !isSubmitting ? Color.brandBlue : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(!isValid || isSubmitting)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if let error = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Submission Failed", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Suggest an Event")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submitSuggestion() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        let suggestion = EventSuggestion(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? " " : description.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            city: city.trimmingCharacters(in: .whitespaces),
            address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespaces),
            locationName: locationName.isEmpty ? nil : locationName.trimmingCharacters(in: .whitespaces),
            category: selectedCategory.rawValue,
            imageURL: nil,
            externalURL: externalURL.isEmpty ? nil : externalURL.trimmingCharacters(in: .whitespaces),
            metro: metroService.selectedMetro.id,
            submitterName: authService.currentUser?.displayName,
            submitterEmail: authService.currentUser?.email
        )

        NSLog("[SuggestEventView] Starting submission for: %@", suggestion.title)

        Task {
            do {
                try await EventSuggestionService.shared.submitSuggestion(suggestion)
                NSLog("[SuggestEventView] ✅ Submission succeeded")
                await MainActor.run {
                    self.isSubmitting = false
                    withAnimation { self.isSubmitted = true }
                }
            } catch {
                NSLog("[SuggestEventView] ❌ Submission failed: %@", error.localizedDescription)
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "Failed to submit: \(error.localizedDescription)"
                }
            }
        }
    }

    private func resetForm() {
        title = ""
        description = ""
        startDate = Date()
        city = ""
        locationName = ""
        address = ""
        externalURL = ""
        selectedCategory = .other
        errorMessage = nil
        isSubmitted = false
    }
}

#Preview {
    NavigationStack {
        SuggestEventView()
    }
}
