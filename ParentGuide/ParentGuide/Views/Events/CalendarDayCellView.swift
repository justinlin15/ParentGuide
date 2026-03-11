//
//  CalendarDayCellView.swift
//  ParentGuide
//

import SwiftUI

struct CalendarDayCellView: View {
    let date: Date
    let events: [Event]
    let isToday: Bool
    var onTap: () -> Void = {}

    private var sortedEvents: [Event] {
        events.sorted { $0.startDate < $1.startDate }
    }

    private var topEvents: [Event] {
        Array(sortedEvents.prefix(3))
    }

    private var remainingCount: Int {
        max(0, events.count - 3)
    }

    var body: some View {
        VStack(spacing: 3) {
            // Day number
            Text("\(date.dayOfMonth)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 24, height: 24)
                .background(isToday ? Color.brandBlue : Color.clear)
                .clipShape(Circle())

            if !events.isEmpty {
                VStack(spacing: 2) {
                    ForEach(topEvents) { event in
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(event.category.color)
                                .frame(width: 3)

                            Text(event.title)
                                .font(.system(size: 8, weight: .medium))
                                .lineLimit(1)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 14)
                        .background(event.category.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }

                    if remainingCount > 0 {
                        Text("+\(remainingCount) more")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(Color.brandBlue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .top)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    CalendarDayCellView(
        date: Date(),
        events: Array(PreviewData.sampleEvents.prefix(8)),
        isToday: true
    )
    .frame(width: 55, height: 100)
}
