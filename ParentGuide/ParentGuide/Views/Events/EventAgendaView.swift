//
//  EventAgendaView.swift
//  ParentGuide
//

import SwiftUI

struct EventAgendaView: View {
    let events: [Event]
    @Binding var selectedDate: Date
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false

    private var datesWithEvents: [Date] {
        let grouped = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        return grouped.keys.sorted()
    }

    private var eventsForSelectedDate: [Event] {
        events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    private var isSelectedDateLocked: Bool {
        guard !subscriptionService.isSubscribed else { return false }
        let horizon = Calendar.current.date(
            byAdding: .day,
            value: AppConstants.freeEventHorizonDays,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
        return Calendar.current.startOfDay(for: selectedDate) > horizon
    }

    var body: some View {
        VStack(spacing: 0) {
            // Horizontal date scroller
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(datesWithEvents, id: \.self) { date in
                            let dateLocked = isDateLocked(date)
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            Button {
                                withAnimation { selectedDate = date }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(date.shortDayName)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    if dateLocked && !isSelected {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                        Text("\(date.dayOfMonth)")
                                            .font(.caption2)
                                    } else {
                                        Text("\(date.dayOfMonth)")
                                            .font(.title3)
                                            .fontWeight(isSelected ? .bold : .regular)
                                    }
                                }
                                .foregroundStyle(isSelected ? .white : (dateLocked ? .secondary : .primary))
                                .frame(width: 48, height: 60)
                                .background(
                                    isSelected
                                        ? Color.brandBlue
                                        : (dateLocked ? Color(.systemGray5) : Color(.systemGray6))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .id(date)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    if let closest = datesWithEvents.min(by: {
                        abs($0.timeIntervalSince(selectedDate)) < abs($1.timeIntervalSince(selectedDate))
                    }) {
                        selectedDate = closest
                        proxy.scrollTo(closest, anchor: .center)
                    }
                }
            }

            Divider()

            // Selected date header
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Events for selected date
            if isSelectedDateLocked {
                // Premium upsell for locked dates
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandBlue.opacity(0.6))

                    Text("\(eventsForSelectedDate.count) event\(eventsForSelectedDate.count == 1 ? "" : "s") on this day")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Free accounts only show 3 days of events.\nGo Premium to unlock every event — plan ahead and never miss out on family fun.")
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

                    Text("Starting at $4.99/month")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else if eventsForSelectedDate.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "calendar",
                    title: "No Events",
                    message: "No events scheduled for this day."
                )
                Spacer()
            } else {
                List {
                    ForEach(eventsForSelectedDate) { event in
                        SubscriptionGatedLink(event: event) {
                            HStack(spacing: 12) {
                                // Time column
                                VStack(spacing: 2) {
                                    if event.isAllDay {
                                        Text("ALL")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                        Text("DAY")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                    } else {
                                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .frame(width: 56)

                                // Color bar
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(event.category.color)
                                    .frame(width: 4)

                                // Event info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin")
                                            .font(.caption2)
                                        Text(event.city)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(lockedContentName: "all upcoming events")
        }
    }

    private func isDateLocked(_ date: Date) -> Bool {
        guard !subscriptionService.isSubscribed else { return false }
        let horizon = Calendar.current.date(
            byAdding: .day,
            value: AppConstants.freeEventHorizonDays,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
        return Calendar.current.startOfDay(for: date) > horizon
    }
}

#Preview {
    NavigationStack {
        EventAgendaView(events: PreviewData.generateMonthEvents(for: Date()), selectedDate: .constant(Calendar.current.startOfDay(for: Date())))
    }
}
