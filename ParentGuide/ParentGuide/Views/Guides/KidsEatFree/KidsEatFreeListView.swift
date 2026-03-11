//
//  KidsEatFreeListView.swift
//  ParentGuide
//

import SwiftUI

struct KidsEatFreeListView: View {
    @State private var viewModel = KidsEatFreeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Kids eat free deals")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                Button {
                    viewModel.showFilter = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text("Filters")
                            .font(.subheadline)
                        if viewModel.activeFilterCount > 0 {
                            Text("\(viewModel.activeFilterCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.brandBlue)
                                .clipShape(Circle())
                        }
                    }
                    .foregroundStyle(viewModel.activeFilterCount > 0 ? Color.brandBlue : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search restaurants...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.applyFilter()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .onChange(of: viewModel.searchText) {
                viewModel.applyFilter()
            }

            Divider()
                .padding(.horizontal, 16)

            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.filteredRestaurants.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No Results",
                    message: "Try adjusting your filters or search."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredRestaurants) { restaurant in
                            NavigationLink(destination: KidsEatFreeDetailView(restaurant: restaurant)) {
                                KidsEatFreeCardView(restaurant: restaurant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await viewModel.loadRestaurants()
        }
        .sheet(isPresented: $viewModel.showFilter) {
            KidsEatFreeFilterView(viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        KidsEatFreeListView()
    }
}
