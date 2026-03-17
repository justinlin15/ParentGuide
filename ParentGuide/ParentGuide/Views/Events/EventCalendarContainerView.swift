//
//  EventCalendarContainerView.swift
//  ParentGuide
//

import SwiftUI

struct EventCalendarContainerView: View {
    @State private var viewModel = EventCalendarViewModel()
    @State private var metroService = MetroService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showSearch = false
    @State private var showFilter = false
    @State private var showDayEvents = false
    @State private var showPaywall = false
    @AppStorage("defaultEventView") private var defaultEventView: String = "Week"

    /// Whether a given event is beyond the free viewing horizon (requires subscription).
    private func requiresSubscription(_ event: Event) -> Bool {
        guard !subscriptionService.isSubscribed else { return false }
        let horizon = Calendar.current.date(byAdding: .day, value: AppConstants.freeEventHorizonDays, to: Date()) ?? Date()
        return event.startDate > horizon
    }

    var body: some View {
        NavigationStack {
            eventContent
                .navigationTitle("Events")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Events")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
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
                .onAppear {
                    Task { await viewModel.reloadIfMetroChanged() }
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
                                    SubscriptionGatedLink(event: event) {
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
                    EventAgendaView(events: viewModel.filteredEventsForCurrentMonth, selectedDate: $viewModel.browsedDate)

                case .map:
                    EventMapView(events: viewModel.filteredEvents, selectedDate: viewModel.browsedDate)
                }
            }

            // Banner ad for non-subscribers
            BannerAdView(adUnitID: AdService.eventsBannerID)
        }
    }
}

#Preview {
    EventCalendarContainerView()
}
