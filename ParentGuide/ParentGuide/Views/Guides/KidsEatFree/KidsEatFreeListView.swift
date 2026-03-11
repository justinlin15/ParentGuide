//
//  KidsEatFreeListView.swift
//  ParentGuide
//

import SwiftUI

struct KidsEatFreeListView: View {
    @State private var viewModel = KidsEatFreeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Kids eat free deals")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    viewModel.showFilter = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text("Filters")
                            .font(.subheadline)
                    }
                    .foregroundStyle(viewModel.selectedCities.isEmpty ? .secondary : Color.brandBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, 16)

            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.filteredRestaurants.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No Results",
                    message: "Try adjusting your filters."
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
