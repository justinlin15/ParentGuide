//
//  AdminDashboardView.swift
//  ParentGuide
//

import SwiftUI

struct AdminDashboardView: View {
    @State private var viewModel = AdminDashboardViewModel()
    @State private var showCreateEvent = false
    @State private var selectedTab: AdminTab = .overview

    enum AdminTab: String, CaseIterable {
        case overview = "Overview"
        case events = "Events"
        case flagged = "Flagged"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                ForEach(AdminTab.allCases, id: \.self) { tab in
                    if tab == .flagged && viewModel.totalFlaggedCount > 0 {
                        Text("\(tab.rawValue) (\(viewModel.totalFlaggedCount))").tag(tab)
                    } else {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if viewModel.isLoading {
                LoadingView(message: "Loading dashboard...")
            } else if let error = viewModel.errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Error",
                    message: error
                )
            } else {
                switch selectedTab {
                case .overview:
                    overviewTab
                case .events:
                    eventsTab
                case .flagged:
                    flaggedTab
                }
            }
        }
        .navigationTitle("Admin Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateEvent = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.loadEvents()
        }
        .task {
            await viewModel.loadEvents()
        }
        .sheet(isPresented: $showCreateEvent) {
            EventFormView(editingEvent: nil) { _ in
                Task { await viewModel.loadEvents() }
            }
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "Total Events", value: "\(viewModel.totalEvents)", icon: "calendar", color: .blue)
                    statCard(title: "Active", value: "\(viewModel.activeEvents)", icon: "checkmark.circle", color: .green)
                    statCard(title: "Expired", value: "\(viewModel.expiredEvents)", icon: "clock.arrow.circlepath", color: .orange)
                    statCard(title: "Added This Week", value: "\(viewModel.eventsAddedThisWeek)", icon: "sparkles", color: .purple)
                    statCard(title: "Featured", value: "\(viewModel.featuredCount)", icon: "star.fill", color: .yellow)
                    statCard(title: "Flagged", value: "\(viewModel.totalFlaggedCount)", icon: "exclamationmark.triangle", color: viewModel.totalFlaggedCount > 0 ? .red : .gray)
                }
                .padding(.horizontal, 16)

                // Events by Source
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events by Source")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    ForEach(viewModel.eventsBySource, id: \.source) { item in
                        HStack {
                            Text(item.source)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            let maxCount = viewModel.eventsBySource.first?.count ?? 1
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.brandBlue.opacity(0.6))
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(max(maxCount, 1)))
                            }
                            .frame(width: 80, height: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 8)

                // Quick Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        quickActionButton(title: "Add Event", icon: "plus.circle.fill", color: .brandBlue) {
                            showCreateEvent = true
                        }

                        quickActionButton(title: "View Flagged", icon: "exclamationmark.triangle.fill", color: .orange) {
                            selectedTab = .flagged
                        }

                        if viewModel.expiredEvents > 0 {
                            quickActionButton(title: "Clean Expired", icon: "trash.fill", color: .red) {
                                Task { await viewModel.bulkDeleteExpired() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
            }
            .padding(.vertical, 8)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Events Tab

    private var eventsTab: some View {
        VStack(spacing: 0) {
            filterBar
            eventsList
        }
        .searchable(text: $viewModel.searchText, prompt: "Search events...")
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("\(viewModel.eventCount) events")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandBlue.opacity(0.1))
                    .clipShape(Capsule())

                Menu {
                    Button("All Metros") { viewModel.selectedMetroFilter = nil }
                    ForEach(viewModel.availableMetros, id: \.self) { metro in
                        Button(metro) { viewModel.selectedMetroFilter = metro }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                        Text(viewModel.selectedMetroFilter ?? "All Metros")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedMetroFilter != nil ? Color.brandBlue : Color(.systemGray5))
                    .foregroundStyle(viewModel.selectedMetroFilter != nil ? .white : .primary)
                    .clipShape(Capsule())
                }

                Menu {
                    Button("All Sources") { viewModel.selectedSourceFilter = nil }
                    ForEach(viewModel.availableSources, id: \.self) { source in
                        Button(source) { viewModel.selectedSourceFilter = source }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text(viewModel.selectedSourceFilter ?? "All Sources")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedSourceFilter != nil ? Color.brandBlue : Color(.systemGray5))
                    .foregroundStyle(viewModel.selectedSourceFilter != nil ? .white : .primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var eventsList: some View {
        List {
            ForEach(viewModel.filteredEvents) { event in
                NavigationLink(destination: EventDetailView(event: event) {
                    Task { await viewModel.loadEvents() }
                } onUpdate: { _ in
                    Task { await viewModel.loadEvents() }
                }) {
                    adminEventRow(event)
                }
            }
            .onDelete { indexSet in
                let events = viewModel.filteredEvents
                for index in indexSet {
                    let event = events[index]
                    Task { await viewModel.deleteEvent(event) }
                }
            }
        }
        .listStyle(.plain)
    }

    private func adminEventRow(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if event.isFeatured {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }

                if event.imageURL == nil || event.imageURL?.isEmpty == true {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if event.latitude == nil {
                    Image(systemName: "location.slash")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 8) {
                Label(event.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)

                Label(event.displayCity, systemImage: "mappin")
                    .font(.caption)

                Spacer()

                Text(event.source ?? "unknown")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.source == "admin" ? Color.brandBlue.opacity(0.2) : Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Flagged Tab

    private var flaggedTab: some View {
        List {
            if !viewModel.eventsMissingCoordinates.isEmpty {
                Section {
                    ForEach(viewModel.eventsMissingCoordinates.prefix(10)) { event in
                        flaggedEventRow(event, issue: "No map coordinates")
                    }
                } header: {
                    Label("Missing Coordinates (\(viewModel.eventsMissingCoordinates.count))", systemImage: "location.slash")
                        .foregroundStyle(.red)
                }
            }

            if !viewModel.duplicateEvents.isEmpty {
                Section {
                    ForEach(viewModel.duplicateEvents.prefix(10), id: \.0.id) { pair in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pair.0.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 12) {
                                Label(pair.0.source ?? "?", systemImage: "1.circle")
                                    .font(.caption)
                                Label(pair.1.source ?? "?", systemImage: "2.circle")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Possible Duplicates (\(viewModel.duplicateEvents.count))", systemImage: "doc.on.doc")
                        .foregroundStyle(.orange)
                }
            }

            if !viewModel.staleEvents.isEmpty {
                Section {
                    ForEach(viewModel.staleEvents.prefix(10)) { event in
                        flaggedEventRow(event, issue: "Expired \(event.startDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    Button(role: .destructive) {
                        Task { await viewModel.bulkDeleteExpired() }
                    } label: {
                        Label("Delete All \(viewModel.staleEvents.count) Expired Events", systemImage: "trash")
                    }
                } header: {
                    Label("Expired Events (\(viewModel.staleEvents.count))", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                }
            }

            if viewModel.totalFlaggedCount == 0 {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("All Clear")
                                .font(.headline)
                            Text("No flagged events found.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func flaggedEventRow(_ event: Event, issue: String) -> some View {
        NavigationLink(destination: EventDetailView(event: event) {
            Task { await viewModel.loadEvents() }
        } onUpdate: { _ in
            Task { await viewModel.loadEvents() }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Text(event.source ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminDashboardView()
    }
}
