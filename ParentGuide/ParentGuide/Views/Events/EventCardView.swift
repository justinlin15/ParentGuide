//
//  EventCardView.swift
//  ParentGuide
//

import SwiftUI

struct EventCardView: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.color)
                .frame(width: 4)

            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(event.formattedTime)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(event.city)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Category icon
            Image(systemName: event.category.iconName)
                .font(.caption)
                .foregroundStyle(event.category.color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

#Preview {
    EventCardView(event: PreviewData.sampleEvents[0])
}
