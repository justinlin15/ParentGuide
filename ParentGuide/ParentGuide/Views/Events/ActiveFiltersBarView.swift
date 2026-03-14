//
//  ActiveFiltersBarView.swift
//  ParentGuide
//

import SwiftUI

struct ActiveFiltersBarView: View {
    @Binding var filter: EventFilter
    var onTap: () -> Void

    var body: some View {
        if filter.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filter.activeFilterDescriptions, id: \.id) { item in
                        filterChip(label: item.label) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.removeFilter(id: item.id)
                            }
                        }
                    }

                    // Clear all button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filter.clearAll()
                        }
                    } label: {
                        Text("Clear All")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .onTapGesture {
                onTap()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.brandBlue)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        ActiveFiltersBarView(
            filter: .constant({
                var f = EventFilter()
                f.priceFilter = .free
                f.selectedCategories = [.outdoorAdventure, .museum]
                return f
            }()),
            onTap: {}
        )

        Spacer()
    }
}
