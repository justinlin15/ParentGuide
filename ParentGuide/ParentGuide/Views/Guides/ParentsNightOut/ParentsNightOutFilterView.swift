//
//  ParentsNightOutFilterView.swift
//  ParentGuide
//

import SwiftUI

struct ParentsNightOutFilterView: View {
    @Bindable var viewModel: ParentsNightOutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Deals") {
                    Button {
                        viewModel.onlyWithPromo.toggle()
                        viewModel.applyFilter()
                    } label: {
                        HStack {
                            Text("Has promo code")
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.onlyWithPromo {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandBlue)
                            }
                        }
                    }
                }

                Section("City") {
                    ForEach(viewModel.allCities, id: \.self) { city in
                        Button {
                            viewModel.toggleCity(city)
                        } label: {
                            HStack {
                                Text(city)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedCities.contains(city) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brandBlue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        viewModel.clearFilter()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ParentsNightOutFilterView(viewModel: ParentsNightOutViewModel())
}
