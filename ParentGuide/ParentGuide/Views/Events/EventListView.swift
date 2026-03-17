//
//  EventListView.swift
//  ParentGuide
//

import SwiftUI

struct EventListView: View {
    let events: [Event]
    var title: String?

    private var groupedEvents: [(Date, [Event])] {
        let grouped = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        if events.isEmpty {
            EmptyStateView(
                icon: "calendar",
                title: "No Events",
                message: "There are no events scheduled for this period."
            )
        } else {
            List {
                ForEach(groupedEvents, id: \.0) { date, dayEvents in
                    Section {
                        ForEach(dayEvents) { event in
                            SubscriptionGatedLink(event: event) {
                                EventCardView(event: event)
                            }
                            .listRowInsets(EdgeInsets())
                        }
                    } header: {
                        Text(date.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        EventListView(events: PreviewData.sampleEvents)
    }
}
