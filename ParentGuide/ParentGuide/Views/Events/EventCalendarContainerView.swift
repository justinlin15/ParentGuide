//
//  EventCalendarContainerView.swift
//  ParentGuide
//

import SwiftUI

struct EventCalendarContainerView: View {
    @State private var viewModel = EventCalendarViewModel()
    @State private var metroService = MetroService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var adminService = AdminService.shared
    @State private var showSearch = false
    @State private var showFilter = false
    @State private var showDayEvents = false
    @State private var showPaywall = false
    @State private var showEventForm = false
    @State private var showHomeLocationSetup = false
    @AppStorage("defaultEventView") private var defaultEventView: String = "Week"

    /// Whether a given event is beyond the free viewing horizon (requires subscription).
    private func requiresSubscription(_ event: Event) -> Bool {
        guard !subscriptionService.hasFullAccess else { return false }
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
                    ToolbarItem(placement: .topBarLeading) {
                        if adminService.isAdmin {
                            Button {
                                showEventForm = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.brandBlue)
                            }
                        }
                    }
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
                .sheet(isPresented: $showEventForm) {
                    EventFormView(editingEvent: nil) { newEvent in
                        viewModel.upsertEvent(newEvent)
                    }
                }
                .sheet(isPresented: $showSearch) {
                    EventSearchView(allEvents: viewModel.filteredEvents)
                }
                .sheet(isPresented: $showFilter) {
                    EventFilterView(
                        filter: $viewModel.filter,
                        hasLocation: viewModel.hasLocation,
                        hasHomeLocation: viewModel.hasHomeLocation,
                        homeCity: AuthService.shared.currentUser?.homeCity,
                        onSetHome: {
                            showFilter = false
                            showHomeLocationSetup = true
                        }
                    )
                }
                .sheet(isPresented: $showHomeLocationSetup) {
                    NavigationStack {
                        HomeLocationSetupView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showHomeLocationSetup = false }
                                }
                            }
                    }
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showDayEvents) {
                    if let selectedDate = viewModel.selectedDate {
                        NavigationStack {
                            if viewModel.isDateLocked(selectedDate) {
                                // Premium upsell for locked dates
                                lockedDateView(date: selectedDate, eventCount: viewModel.filteredEventsForDate(selectedDate).count)
                            } else {
                                List {
                                    ForEach(viewModel.filteredEventsForDate(selectedDate)) { event in
                                        SubscriptionGatedLink(event: event) {
                                            EventCardView(event: event)
                                        }
                                        .listRowInsets(EdgeInsets())
                                    }
                                }
                                .listStyle(.plain)
                            }
                        }
                        .navigationTitle(selectedDate.formatted(date: .complete, time: .omitted))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showDayEvents = false }
                            }
                        }
                        .sheet(isPresented: $showPaywall) {
                            PaywallView(lockedContentName: "all upcoming events")
                        }
                        .presentationDetents([.medium, .large])
                    }
                }
        }
    }

    // MARK: - Locked Date Upsell

    private func lockedDateView(date: Date, eventCount: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandBlue.opacity(0.6))

            Text(date.formatted(date: .complete, time: .omitted))
                .font(.headline)

            Text("\(eventCount) event\(eventCount == 1 ? "" : "s") waiting for you")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Free accounts only show 3 days of events.\nUpgrade to Premium to unlock every event, every day — never miss a moment with your family.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Unlock All Events")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Text("As low as $4/month")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
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
                    EventMapView(events: viewModel.filteredEvents, selectedDate: $viewModel.browsedDate)
                }
            }

            // Banner ad for non-subscribers
            BannerAdView(adUnitID: AdService.AdUnitID.banner)
        }
    }
}

#Preview {
    EventCalendarContainerView()
}
