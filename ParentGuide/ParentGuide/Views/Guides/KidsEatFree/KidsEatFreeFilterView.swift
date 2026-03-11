//
//  KidsEatFreeFilterView.swift
//  ParentGuide
//

import SwiftUI

struct KidsEatFreeFilterView: View {
    @Bindable var viewModel: KidsEatFreeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Filter by City") {
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
    KidsEatFreeFilterView(viewModel: KidsEatFreeViewModel())
}
