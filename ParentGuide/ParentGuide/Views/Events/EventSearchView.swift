//
//  EventSearchView.swift
//  ParentGuide
//

import SwiftUI

struct EventSearchView: View {
    let allEvents: [Event]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredEvents: [Event] {
        if searchText.isEmpty { return [] }
        let query = searchText.lowercased()
        return allEvents.filter {
            $0.title.lowercased().contains(query) ||
            $0.city.lowercased().contains(query) ||
            $0.category.rawValue.lowercased().contains(query) ||
            $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Text("Search \"Featured\" to see the best events this month.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)

                        // Quick search suggestions
                        FlowLayout(spacing: 8) {
                            ForEach(["Featured", "Free", "Toddler", "Library", "Outdoor", "Craft"], id: \.self) { tag in
                                Button {
                                    searchText = tag
                                } label: {
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer()
                    }
                } else if filteredEvents.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "Try a different search term."
                    )
                } else {
                    List(filteredEvents) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            EventCardView(event: event)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search events...")
            .navigationTitle("Search Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: width, height: y + rowHeight), positions)
    }
}

#Preview {
    EventSearchView(allEvents: PreviewData.sampleEvents)
}
