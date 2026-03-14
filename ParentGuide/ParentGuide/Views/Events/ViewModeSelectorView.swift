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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }

                Spacer()

                Text(viewModel.currentMonth.monthYearString)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    viewModel.goToNextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // View mode selector row
            HStack(spacing: 4) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedViewMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedViewMode == mode ? .bold : .medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
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
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())

                        if viewModel.filter.activeFilterCount > 0 {
                            Text("\(viewModel.filter.activeFilterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .offset(x: 6, y: -2)
                        }
                    }
                }

                Button(action: onSearchTap) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
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
