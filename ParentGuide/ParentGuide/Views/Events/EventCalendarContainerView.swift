//
//  EventCalendarContainerView.swift
//  ParentGuide
//

import SwiftUI

struct EventCalendarContainerView: View {
    @State private var viewModel = EventCalendarViewModel()
    @State private var adminService = AdminService.shared
    @State private var showSearch = false
    @State private var showDayEvents = false
    @State private var showCreateEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ViewModeSelectorView(viewModel: viewModel) {
                    showSearch = true
                }

                switch viewModel.selectedViewMode {
                case .month:
                    if viewModel.isLoading {
                        LoadingView(message: "Loading events...")
                    } else {
                        CalendarMonthView(viewModel: viewModel) { date in
                            showDayEvents = true
                        }
                    }

                case .list:
                    EventListView(events: viewModel.events)

                case .week:
                    EventAgendaView(events: viewModel.events)

                case .map:
                    EventMapView(events: viewModel.events)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("What's on the schedule today?")
                        .font(.headline)
                }

                if adminService.isAdmin {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateEvent = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .task {
                await adminService.checkAdminStatus()
                await viewModel.loadEvents()
            }
            .sheet(isPresented: $showSearch) {
                EventSearchView(allEvents: viewModel.events)
            }
            .sheet(isPresented: $showCreateEvent) {
                EventFormView(editingEvent: nil) { _ in
                    // Refresh events after creating
                    Task { await viewModel.loadEvents() }
                }
            }
            .sheet(isPresented: $showDayEvents) {
                if let selectedDate = viewModel.selectedDate {
                    NavigationStack {
                        List {
                            ForEach(viewModel.eventsForDate(selectedDate)) { event in
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
}

#Preview {
    EventCalendarContainerView()
}
