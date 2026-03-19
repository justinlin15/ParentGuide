//
//  DraftEventsView.swift
//  ParentGuide
//
//  Admin review queue for pipeline events flagged as "draft".
//  These are scraper events that couldn't be verified against a real venue URL,
//  which may indicate honeypot watermark data injected by the source site.
//
//  Admins can: preview individual events, bulk-select, approve (publish) or reject.
//

import SwiftUI

@Observable
private final class DraftEventsViewModel {
    var events: [Event] = []
    var isLoading = false
    var errorMessage: String?
    var selectedIDs: Set<String> = []
    var isSelecting = false
    var isBulkProcessing = false

    var hasSelection: Bool { !selectedIDs.isEmpty }

    var sortedEvents: [Event] {
        events.sorted { $0.startDate < $1.startDate }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            events = try await EventService.shared.fetchDraftEvents()
        } catch {
            errorMessage = error.localizedDescription
            NSLog("[DraftEventsVM] Load error: %@", error.localizedDescription)
        }
        isLoading = false
    }

    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(events.map(\.id))
    }

    func clearSelection() {
        selectedIDs = []
        isSelecting = false
    }

    /// Publish (approve) selected events.
    func approveSelected() async {
        isBulkProcessing = true
        let toApprove = events.filter { selectedIDs.contains($0.id) }
        var succeeded = 0
        var failed = 0
        for event in toApprove {
            do {
                _ = try await EventService.shared.publishEvent(event)
                succeeded += 1
            } catch {
                NSLog("[DraftEventsVM] Approve failed for %@: %@", event.id, error.localizedDescription)
                failed += 1
            }
        }
        NSLog("[DraftEventsVM] Approved %d, failed %d", succeeded, failed)
        events.removeAll { selectedIDs.contains($0.id) }
        clearSelection()
        isBulkProcessing = false
    }

    /// Reject selected events (hidden from all users, not deleted).
    func rejectSelected() async {
        isBulkProcessing = true
        let toReject = events.filter { selectedIDs.contains($0.id) }
        var succeeded = 0
        var failed = 0
        for event in toReject {
            do {
                _ = try await EventService.shared.rejectEvent(event)
                succeeded += 1
            } catch {
                NSLog("[DraftEventsVM] Reject failed for %@: %@", event.id, error.localizedDescription)
                failed += 1
            }
        }
        NSLog("[DraftEventsVM] Rejected %d, failed %d", succeeded, failed)
        events.removeAll { selectedIDs.contains($0.id) }
        clearSelection()
        isBulkProcessing = false
    }

    /// Approve a single event immediately.
    func approveSingle(_ event: Event) {
        Task {
            do {
                _ = try await EventService.shared.publishEvent(event)
                events.removeAll { $0.id == event.id }
            } catch {
                NSLog("[DraftEventsVM] Approve error: %@", error.localizedDescription)
            }
        }
    }

    /// Reject a single event immediately.
    func rejectSingle(_ event: Event) {
        Task {
            do {
                _ = try await EventService.shared.rejectEvent(event)
                events.removeAll { $0.id == event.id }
            } catch {
                NSLog("[DraftEventsVM] Reject error: %@", error.localizedDescription)
            }
        }
    }
}

struct DraftEventsView: View {
    @State private var vm = DraftEventsViewModel()
    @State private var eventToReject: Event?
    @State private var showRejectConfirm = false
    @State private var showBulkRejectConfirm = false

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingView(message: "Loading draft events...")
            } else if let error = vm.errorMessage {
                errorView(error)
            } else if vm.events.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield",
                    title: "No Drafts to Review",
                    message: "All pipeline events have been verified and published."
                )
            } else {
                eventsList
            }
        }
        .navigationTitle("Draft Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .refreshable {
            await vm.load()
        }
        .task {
            await vm.load()
        }
        // Single-event reject confirmation
        .alert("Reject Event", isPresented: $showRejectConfirm) {
            Button("Reject", role: .destructive) {
                if let event = eventToReject {
                    vm.rejectSingle(event)
                }
            }
            Button("Cancel", role: .cancel) { eventToReject = nil }
        } message: {
            if let event = eventToReject {
                Text("Reject \"\(event.title)\"? It will be hidden from users but not deleted.")
            }
        }
        // Bulk reject confirmation
        .alert("Reject \(vm.selectedIDs.count) Events?", isPresented: $showBulkRejectConfirm) {
            Button("Reject All", role: .destructive) {
                Task { await vm.rejectSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The selected events will be hidden from users but not deleted. You can re-approve them from the Admin Dashboard.")
        }
        // Processing overlay
        .overlay {
            if vm.isBulkProcessing {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Events List

    private var eventsList: some View {
        List(vm.sortedEvents) { event in
            Group {
                if vm.isSelecting {
                    draftEventRow(event)
                } else {
                    NavigationLink(destination: EventDetailView(event: event)) {
                        draftEventRow(event)
                    }
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    vm.approveSingle(event)
                } label: {
                    Label("Publish", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    eventToReject = event
                    showRejectConfirm = true
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                }
            }
        }
        .listStyle(.plain)
    }

    private func draftEventRow(_ event: Event) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox (shown when in selection mode)
            if vm.isSelecting {
                Image(systemName: vm.selectedIDs.contains(event.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(vm.selectedIDs.contains(event.id) ? Color.brandBlue : .secondary)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.15), value: vm.selectedIDs.contains(event.id))
                    .onTapGesture { vm.toggleSelection(event.id) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Label(event.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    if !event.city.isEmpty {
                        Label(event.displayCity, systemImage: "mappin")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    // Category pill
                    Text(event.category.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandBlue.opacity(0.15))
                        .clipShape(Capsule())

                    // Source badge
                    if let source = event.source {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Honeypot risk indicator
                    if event.externalURL?.contains("google.com/search") == true || event.externalURL == nil {
                        Label("No verified URL", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                // Swipe hint (when not in selection mode)
                if !vm.isSelecting {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.caption2)
                        Text("Tap to preview · Swipe to publish or reject")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if vm.isSelecting {
                vm.toggleSelection(event.id)
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Could not load draft events")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task { await vm.load() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if vm.isSelecting {
            // Left: cancel
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { vm.clearSelection() }
            }

            // Center: select all / count
            ToolbarItem(placement: .principal) {
                Button(vm.selectedIDs.count == vm.events.count ? "Deselect All" : "Select All") {
                    if vm.selectedIDs.count == vm.events.count {
                        vm.selectedIDs = []
                    } else {
                        vm.selectAll()
                    }
                }
                .font(.subheadline)
            }

            // Right: bulk actions
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await vm.approveSelected() }
                    } label: {
                        Label("Publish \(vm.selectedIDs.count) Events", systemImage: "checkmark.circle")
                    }
                    .disabled(!vm.hasSelection)

                    Button(role: .destructive) {
                        showBulkRejectConfirm = true
                    } label: {
                        Label("Reject \(vm.selectedIDs.count) Events", systemImage: "xmark.circle")
                    }
                    .disabled(!vm.hasSelection)
                } label: {
                    Text(vm.hasSelection ? "Actions (\(vm.selectedIDs.count))" : "Actions")
                        .font(.subheadline)
                }
                .disabled(!vm.hasSelection)
            }
        } else {
            // Normal mode — show Select button and count
            ToolbarItem(placement: .primaryAction) {
                Button("Select") {
                    vm.isSelecting = true
                }
                .disabled(vm.events.isEmpty)
            }

            ToolbarItem(placement: .principal) {
                Text("\(vm.events.count) pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DraftEventsView()
    }
}
