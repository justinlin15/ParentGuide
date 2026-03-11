//
//  ParentsNightOutListView.swift
//  ParentGuide
//

import SwiftUI

struct ParentsNightOutListView: View {
    @State private var viewModel = ParentsNightOutViewModel()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Parents night out")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Give your kids a fun night while you enjoy a much needed date!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, 16)

            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.providers.isEmpty {
                EmptyStateView(
                    icon: "figure.2.and.child.holdinghands",
                    title: "No Providers",
                    message: "Check back later for Parents Night Out options."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.providers) { provider in
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
    }
}

#Preview {
    NavigationStack {
        ParentsNightOutListView()
    }
}
