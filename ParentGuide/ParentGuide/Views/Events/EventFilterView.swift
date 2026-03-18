//
//  EventFilterView.swift
//  ParentGuide
//

import SwiftUI

struct EventFilterView: View {
    @Binding var filter: EventFilter
    var hasLocation: Bool
    var hasHomeLocation: Bool = false
    var homeCity: String? = nil
    var onSetHome: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SortBySection(sortBy: $filter.sortBy, hasLocation: hasLocation)
                    Divider()
                    DateRangeSection(dateRange: $filter.dateRange, customStartDate: $filter.customStartDate, customEndDate: $filter.customEndDate)
                    Divider()
                    DistanceSection(
                        distanceOption: $filter.distanceOption,
                        distanceFrom: $filter.distanceFrom,
                        hasLocation: hasLocation,
                        hasHomeLocation: hasHomeLocation,
                        homeCity: homeCity,
                        onSetHome: onSetHome
                    )
                    Divider()
                    PriceSection(priceFilter: $filter.priceFilter)
                    Divider()
                    CategorySection(selectedCategories: $filter.selectedCategories)
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        withAnimation { filter.clearAll() }
                    }
                    .foregroundStyle(filter.hasActiveFilters ? Color.brandBlue : .secondary)
                    .disabled(!filter.hasActiveFilters)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Sort By Section

private struct SortBySection: View {
    @Binding var sortBy: EventSortOption
    var hasLocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sort By")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(EventSortOption.allCases, id: \.self) { option in
                    SortOptionButton(option: option, isSelected: sortBy == option, isDisabled: option == .distance && !hasLocation) {
                        sortBy = option
                    }
                }
            }
        }
    }
}

private struct SortOptionButton: View {
    let option: EventSortOption
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !isDisabled { action() }
        } label: {
            Label(option.rawValue, systemImage: option.iconName)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isDisabled ? Color.gray : (isSelected ? Color.white : Color.primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brandBlue : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
    }
}

// MARK: - Date Range Section

private struct DateRangeSection: View {
    @Binding var dateRange: DateRangeOption
    @Binding var customStartDate: Date?
    @Binding var customEndDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(DateRangeOption.allCases.filter { $0 != .custom }, id: \.self) { option in
                    FilterChipButton(label: option.displayName, isSelected: dateRange == option) {
                        dateRange = option
                    }
                }

                Button {
                    dateRange = .custom
                } label: {
                    Label("Custom", systemImage: "calendar")
                        .font(.caption)
                        .fontWeight(dateRange == .custom ? .bold : .medium)
                        .foregroundStyle(dateRange == .custom ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(dateRange == .custom ? Color.brandBlue : Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }

            if dateRange == .custom {
                VStack(spacing: 12) {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { customStartDate ?? Date() },
                            set: { customStartDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .font(.subheadline)

                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { customEndDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())! },
                            set: { customEndDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .font(.subheadline)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Distance Section

private struct DistanceSection: View {
    @Binding var distanceOption: DistanceOption
    @Binding var distanceFrom: DistanceFromOption
    var hasLocation: Bool
    var hasHomeLocation: Bool
    var homeCity: String?
    var onSetHome: (() -> Void)?

    private var isLocationAvailable: Bool {
        distanceFrom == .currentLocation ? hasLocation : hasHomeLocation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Distance")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Distance from selector
            HStack(spacing: 8) {
                ForEach(DistanceFromOption.allCases, id: \.self) { option in
                    let icon = option == .currentLocation ? "location.fill" : "house.fill"
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            distanceFrom = option
                        }
                    } label: {
                        Label(option.rawValue, systemImage: icon)
                            .font(.caption)
                            .fontWeight(distanceFrom == option ? .bold : .medium)
                            .foregroundStyle(distanceFrom == option ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(distanceFrom == option ? Color.brandBlue : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }

            // Status/warning messages
            if distanceFrom == .currentLocation && !hasLocation {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash")
                        .font(.caption)
                    Text("Enable location services in Settings to use this filter")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .padding(.vertical, 4)
            } else if distanceFrom == .home && !hasHomeLocation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "house.circle")
                            .font(.caption)
                        Text("Set your home location to use this filter")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)

                    if let onSetHome {
                        Button {
                            onSetHome()
                        } label: {
                            Label("Set Home Location", systemImage: "house.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.brandBlue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            } else if distanceFrom == .home, let city = homeCity {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.caption)
                    Text("From \(city)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Distance radius options
            HStack(spacing: 8) {
                ForEach(DistanceOption.allCases, id: \.self) { option in
                    let disabled = !isLocationAvailable && option != .unlimited
                    FilterChipButton(
                        label: option.displayName,
                        isSelected: distanceOption == option,
                        isDisabled: disabled
                    ) {
                        distanceOption = option
                    }
                }
            }
        }
    }
}

// MARK: - Price Section

private struct PriceSection: View {
    @Binding var priceFilter: PriceFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Price")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(PriceFilter.allCases, id: \.self) { option in
                    PriceChipButton(option: option, isSelected: priceFilter == option) {
                        priceFilter = option
                    }
                }
            }
        }
    }
}

private struct PriceChipButton: View {
    let option: PriceFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if option == .free {
                    Image(systemName: "checkmark.circle.fill").font(.caption2)
                } else if option == .paid {
                    Image(systemName: "dollarsign.circle.fill").font(.caption2)
                }
                Text(option.rawValue).font(.caption)
            }
            .fontWeight(isSelected ? .bold : .medium)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .clipShape(Capsule())
        }
    }

    private var backgroundColor: Color {
        guard isSelected else { return Color(.systemGray6) }
        switch option {
        case .all: return Color.brandBlue
        case .free: return .green
        case .paid: return .orange
        }
    }
}

// MARK: - Category Section

private struct CategorySection: View {
    @Binding var selectedCategories: Set<EventCategory>

    private var filteredCategories: [EventCategory] {
        EventCategory.allCases.filter { $0 != .subscriberMeetup }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(filteredCategories, id: \.self) { category in
                    CategoryChipButton(
                        category: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }

            if !selectedCategories.isEmpty {
                Button {
                    selectedCategories = []
                } label: {
                    Text("Clear categories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct CategoryChipButton: View {
    let category: EventCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(category.displayName, systemImage: category.iconName)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSelected ? category.color : Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Reusable Filter Chip Button

private struct FilterChipButton: View {
    let label: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            if !isDisabled { action() }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isDisabled ? Color.gray : (isSelected ? Color.white : Color.primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brandBlue : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
    }
}

#Preview {
    EventFilterView(
        filter: .constant(EventFilter()),
        hasLocation: true,
        hasHomeLocation: true,
        homeCity: "Irvine"
    )
}
