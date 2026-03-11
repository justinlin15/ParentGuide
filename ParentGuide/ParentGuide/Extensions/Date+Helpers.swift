//
//  Date+Helpers.swift
//  ParentGuide
//

import Foundation

nonisolated extension Date {
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)!.start
    }

    var endOfMonth: Date {
        let interval = Calendar.current.dateInterval(of: .month, for: self)!
        return Calendar.current.date(byAdding: .second, value: -1, to: interval.end)!
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var monthYearString: String {
        formatted(.dateTime.month(.wide).year())
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }

    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var shortDayName: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)!.count
    }

    var firstWeekdayOfMonth: Int {
        Calendar.current.component(.weekday, from: startOfMonth)
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self)!
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isSameMonth(as other: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: self) == cal.component(.month, from: other)
            && cal.component(.year, from: self) == cal.component(.year, from: other)
    }

    static func datesInMonth(for date: Date) -> [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let startOfMonth = date.startOfMonth
        return range.map { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)!
        }
    }
}
