//
//  CalendarMonthView.swift
//  ParentGuide
//

import SwiftUI

struct CalendarMonthView: View {
    @Bindable var viewModel: EventCalendarViewModel
    var onDateSelected: (Date) -> Void = { _ in }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    let firstWeekday = viewModel.currentMonth.firstWeekdayOfMonth
                    ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                        Color.clear.frame(minHeight: 100)
                    }

                    let dates = Date.datesInMonth(for: viewModel.currentMonth)
                    ForEach(dates, id: \.self) { date in
                        CalendarDayCellView(
                            date: date,
                            events: viewModel.filteredEventsForDate(date),
                            isToday: date.isToday,
                            isLocked: viewModel.isDateLocked(date),
                            onTap: {
                                viewModel.selectedDate = date
                                onDateSelected(date)
                            }
                        )
                    }
                }
                .background(Color(.systemGray6).opacity(0.3))

                VStack(spacing: 12) {
                    Text("Tap a day to see events")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                        ForEach(EventCategory.allCases.prefix(8), id: \.self) { category in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text(category.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    let vm = EventCalendarViewModel()
    CalendarMonthView(viewModel: vm)
        .task { await vm.loadEvents() }
}
