//
//  ViewModeSelectorView.swift
//  ParentGuide
//

import SwiftUI

struct ViewModeSelectorView: View {
    @Bindable var viewModel: EventCalendarViewModel
    var onSearchTap: () -> Void = {}
    var onFilterTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation row
            HStack {
                Button {
                    viewModel.goToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(viewModel.currentMonth.monthYearString)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    viewModel.goToNextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // View mode selector row
            HStack(spacing: 0) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedViewMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(viewModel.selectedViewMode == mode ? .bold : .medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedViewMode == mode
                                    ? Color.white.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                }

                // Filter button with badge
                Button(action: onFilterTap) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)

                        if viewModel.filter.activeFilterCount > 0 {
                            Text("\(viewModel.filter.activeFilterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }

                Button(action: onSearchTap) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.brandBlue)
    }
}

#Preview {
    ViewModeSelectorView(viewModel: EventCalendarViewModel())
}
