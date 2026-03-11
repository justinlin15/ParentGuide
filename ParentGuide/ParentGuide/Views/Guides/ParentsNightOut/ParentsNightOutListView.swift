//
//  ParentsNightOutListView.swift
//  ParentGuide
//

import SwiftUI

struct ParentsNightOutListView: View {
    @State private var viewModel = ParentsNightOutViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parents night out")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Give your kids a fun night while you enjoy a much needed date!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                TextField("Search providers...", text: $viewModel.searchText)
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
            } else if viewModel.filteredProviders.isEmpty {
                EmptyStateView(
                    icon: "figure.2.and.child.holdinghands",
                    title: "No Results",
                    message: "Try adjusting your filters or search."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredProviders) { provider in
                            NavigationLink(destination: ParentsNightOutDetailView(provider: provider)) {
                                ParentsNightOutCardView(provider: provider)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await viewModel.loadProviders()
        }
        .sheet(isPresented: $viewModel.showFilter) {
            ParentsNightOutFilterView(viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        ParentsNightOutListView()
    }
}
