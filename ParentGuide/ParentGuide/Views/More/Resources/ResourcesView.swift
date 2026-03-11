//
//  ResourcesView.swift
//  ParentGuide
//

import SwiftUI

struct ResourcesView: View {
    private let resources = PreviewData.sampleResources

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Resource downloads")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(resources) { resource in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .frame(width: 140, height: 180)
                            VStack {
                                Image(systemName: "doc.richtext")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.brandBlue)
                                Text("PDF")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(resource.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Resources")
    }
}

#Preview {
    NavigationStack {
        ResourcesView()
    }
}
