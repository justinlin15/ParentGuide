//
//  AdminReviewQueueView.swift
//  ParentGuide
//

import SwiftUI

struct AdminReviewQueueView: View {
    @State private var suggestions: [EventSuggestion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRejectAlert = false
    @State private var suggestionToReject: EventSuggestion?

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading suggestions...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Could not load suggestions")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        Task { await loadSuggestions() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if suggestions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Pending Suggestions",
                    message: "All event suggestions have been reviewed."
                )
            } else {
                suggestionsList
            }
        }
        .navigationTitle("Review Queue")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadSuggestions()
        }
        .task {
            await loadSuggestions()
        }
        .alert("Reject Suggestion", isPresented: $showRejectAlert) {
            Button("Reject", role: .destructive) {
                if let suggestion = suggestionToReject {
                    rejectSuggestion(suggestion)
                }
            }
            Button("Cancel", role: .cancel) {
                suggestionToReject = nil
            }
        } message: {
            if let suggestion = suggestionToReject {
                Text("Are you sure you want to reject \"\(suggestion.title)\"?")
            }
        }
    }

    private var suggestionsList: some View {
        List {
            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            suggestionToReject = suggestion
                            showRejectAlert = true
                        } label: {
                            Label("Reject", systemImage: "xmark.circle")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            approveSuggestion(suggestion)
                        } label: {
                            Label("Approve", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.plain)
    }

    private func suggestionRow(_ suggestion: EventSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion.title)
                .font(.subheadline)
                .fontWeight(.medium)

            if !suggestion.eventDescription.isEmpty {
                Text(suggestion.eventDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label(suggestion.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption)
                Label(suggestion.city, systemImage: "mappin")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text(suggestion.category)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.brandBlue.opacity(0.2))
                    .clipShape(Capsule())

                if let name = suggestion.submitterName {
                    Label(name, systemImage: "person")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(suggestion.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Swipe hint
            HStack {
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text("Swipe right to approve, left to reject")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func loadSuggestions() async {
        isLoading = true
        do {
            suggestions = try await EventSuggestionService.shared.fetchPendingSuggestions()
        } catch {
            errorMessage = error.localizedDescription
            NSLog("[AdminReviewQueue] Load error: %@", error.localizedDescription)
        }
        isLoading = false
    }

    private func approveSuggestion(_ suggestion: EventSuggestion) {
        Task {
            do {
                try await EventSuggestionService.shared.approveSuggestion(suggestion)
                suggestions.removeAll { $0.id == suggestion.id }
            } catch {
                NSLog("[AdminReviewQueue] Approve error: %@", error.localizedDescription)
            }
        }
    }

    private func rejectSuggestion(_ suggestion: EventSuggestion) {
        Task {
            do {
                try await EventSuggestionService.shared.rejectSuggestion(suggestion)
                suggestions.removeAll { $0.id == suggestion.id }
            } catch {
                NSLog("[AdminReviewQueue] Reject error: %@", error.localizedDescription)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminReviewQueueView()
    }
}
