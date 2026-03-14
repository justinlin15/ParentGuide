//
//  EventCalendarContainerView.swift
//  ParentGuide
//

import SwiftUI

struct EventCalendarContainerView: View {
    @State private var viewModel = EventCalendarViewModel()
    @State private var metroService = MetroService.shared
    @State private var showSearch = false
    @State private var showFilter = false
    @State private var showDayEvents = false
    @AppStorage("defaultEventView") private var defaultEventView: String = "Week"

    var body: some View {
        NavigationStack {
            eventContent
                .navigationTitle("Events")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        MetroSwitcherView()
                    }
                }
                .task {
                    // Apply saved default view mode
                    if let mode = CalendarViewMode(rawValue: defaultEventView) {
                        viewModel.selectedViewMode = mode
                    }
                    await viewModel.loadEvents()
                }
                .onChange(of: metroService.selectedMetro.id) {
                    Task { await viewModel.loadEvents() }
                }
                .sheet(isPresented: $showSearch) {
                    EventSearchView(allEvents: viewModel.filteredEvents)
                }
                .sheet(isPresented: $showFilter) {
                    EventFilterView(
                        filter: $viewModel.filter,
                        hasLocation: viewModel.hasLocation
                    )
                }
                .sheet(isPresented: $showDayEvents) {
                    if let selectedDate = viewModel.selectedDate {
                        NavigationStack {
                            List {
                                ForEach(viewModel.filteredEventsForDate(selectedDate)) { event in
                                    NavigationLink(destination: EventDetailView(event: event)) {
                                        EventCardView(event: event)
                                    }
                                    .listRowInsets(EdgeInsets())
                                }
                            }
                            .listStyle(.plain)
                            .navigationTitle(selectedDate.formatted(date: .complete, time: .omitted))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showDayEvents = false }
                                }
                            }
                        }
                        .presentationDetents([.medium, .large])
                    }
                }
        }
    }

    // MARK: - Event Content

    @ViewBuilder
    private var eventContent: some View {
        VStack(spacing: 0) {
            ViewModeSelectorView(viewModel: viewModel) {
                showSearch = true
            } onFilterTap: {
                showFilter = true
            }

            // Active filters bar
            ActiveFiltersBarView(filter: $viewModel.filter) {
                showFilter = true
            }

            if viewModel.isLoading {
                LoadingView(message: "Loading events...")
            } else {
                switch viewModel.selectedViewMode {
                case .month:
                    CalendarMonthView(viewModel: viewModel) { date in
                        showDayEvents = true
                    }

                case .list:
                    EventListView(events: viewModel.filteredEventsForCurrentMonth)

                case .week:
                    EventAgendaView(events: viewModel.filteredEventsForCurrentMonth)

                case .map:
                    EventMapView(events: viewModel.filteredEvents)
                }
            }
        }
    }
}

#Preview {
    EventCalendarContainerView()
}
