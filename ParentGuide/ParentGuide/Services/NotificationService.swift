//
//  NotificationService.swift
//  ParentGuide
//

import UserNotifications
import Foundation

@Observable
final class NotificationService {
    static let shared = NotificationService()

    var isAuthorized = false
    private let center = UNUserNotificationCenter.current()

    /// How far before an event to send the reminder (in seconds)
    private let defaultReminderOffset: TimeInterval = -3600 // 1 hour before

    private init() {
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization

    @MainActor
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("[NotificationService] Auth request failed: \(error)")
            return false
        }
    }

    @MainActor
    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Reminders for Favorited Events

    /// Schedule a local notification reminder for an event.
    /// Sends a notification 1 hour before the event starts.
    func scheduleReminder(for event: Event) async {
        // Ensure authorized
        if !isAuthorized {
            let granted = await MainActor.run {
                Task { await requestAuthorization() }
            }
            // Small delay to let authorization complete
            try? await Task.sleep(for: .milliseconds(500))
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Don't schedule notifications for past events
        let reminderDate = event.startDate.addingTimeInterval(defaultReminderOffset)
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "🎉 Event Reminder"
        content.body = "\(event.title) starts in 1 hour!"
        content.sound = .default

        // Add event details as subtitle
        if let locationName = event.locationName {
            content.subtitle = "📍 \(locationName)"
        } else {
            content.subtitle = "📍 \(event.city)"
        }

        // Store event info for deep linking
        content.userInfo = [
            "eventId": event.id,
            "eventTitle": event.title,
        ]

        // Create time-based trigger
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationID(for: event.id),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("[NotificationService] Scheduled reminder for \(event.title) at \(reminderDate)")
        } catch {
            print("[NotificationService] Failed to schedule: \(error)")
        }
    }

    /// Cancel the reminder notification for an event.
    func cancelReminder(for eventID: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: [notificationID(for: eventID)]
        )
        print("[NotificationService] Cancelled reminder for \(eventID)")
    }

    /// Schedule reminders for all currently favorited events.
    func scheduleRemindersForAllFavorites() async {
        let favoriteIDs = FavoritesService.shared.favoriteIDs
        guard !favoriteIDs.isEmpty else { return }

        do {
            let events = try await EventService.shared.fetchFavoriteEvents(ids: favoriteIDs)
            for event in events where event.startDate > Date() {
                await scheduleReminder(for: event)
            }
            print("[NotificationService] Scheduled \(events.count) favorite reminders")
        } catch {
            print("[NotificationService] Failed to fetch favorites: \(error)")
        }
    }

    /// Cancel all pending event reminders.
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private func notificationID(for eventID: String) -> String {
        "event_reminder_\(eventID)"
    }
}
