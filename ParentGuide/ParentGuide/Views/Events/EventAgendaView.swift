//
//  EventAgendaView.swift
//  ParentGuide
//

import SwiftUI

struct EventAgendaView: View {
    let events: [Event]
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

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

    var body: some View {
        VStack(spacing: 0) {
            // Horizontal date scroller
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(datesWithEvents, id: \.self) { date in
                            Button {
                                withAnimation { selectedDate = date }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(date.shortDayName)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    Text("\(date.dayOfMonth)")
                                        .font(.title3)
                                        .fontWeight(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                                }
                                .foregroundStyle(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                                .frame(width: 48, height: 60)
                                .background(
                                    Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                        ? Color.brandBlue
                                        : Color(.systemGray6)
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
            if eventsForSelectedDate.isEmpty {
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
                        NavigationLink(destination: EventDetailView(event: event)) {
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
    }
}

#Preview {
    NavigationStack {
        EventAgendaView(events: PreviewData.generateMonthEvents(for: Date()))
    }
}
