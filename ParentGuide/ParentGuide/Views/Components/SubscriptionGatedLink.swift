//
//  SubscriptionGatedLink.swift
//  ParentGuide
//

import SwiftUI

/// A NavigationLink that gates events beyond the free horizon behind a paywall.
/// Free users see all events in lists, but tapping one >3 days out shows the paywall
/// instead of navigating to EventDetailView.
struct SubscriptionGatedLink<Label: View>: View {
    let event: Event
    @ViewBuilder let label: () -> Label

    @State private var showPaywall = false
    @State private var subscriptionService = SubscriptionService.shared

    /// Whether this event requires a subscription to view details.
    private var isLocked: Bool {
        guard !subscriptionService.hasFullAccess else { return false }
        let horizon = Calendar.current.date(
            byAdding: .day,
            value: AppConstants.freeEventHorizonDays,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
        return event.startDate > horizon
    }

    var body: some View {
        if isLocked {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    label()
                    Spacer(minLength: 0)
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(lockedContentName: "all upcoming events")
            }
        } else {
            NavigationLink(destination: EventDetailView(event: event)) {
                label()
            }
        }
    }
}
