//
//  NotificationsView.swift
//  ParentGuide
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    // Sample notifications for now
    private let notifications: [(icon: String, title: String, subtitle: String, time: String, isNew: Bool)] = [
        ("calendar.badge.plus", "New Events Added", "15 new events added for this weekend", "2h ago", true),
        ("star.fill", "Event Updated", "Farmers Market at Great Park time changed to 9 AM", "5h ago", true),
        ("bell.fill", "Reminder", "Free Movie in the Park is tomorrow at 6 PM", "1d ago", false),
        ("person.3.fill", "Subscriber Meetup", "New Mom's Night Out event posted for March 20", "2d ago", false),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(notifications.enumerated()), id: \.offset) { _, notification in
                    HStack(spacing: 12) {
                        Image(systemName: notification.icon)
                            .font(.title3)
                            .foregroundStyle(Color.brandBlue)
                            .frame(width: 40, height: 40)
                            .background(Color.brandBlue.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(notification.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if notification.isNew {
                                    Circle()
                                        .fill(Color.brandBlue)
                                        .frame(width: 8, height: 8)
                                }
                            }

                            Text(notification.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            Text(notification.time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NotificationsView()
}
