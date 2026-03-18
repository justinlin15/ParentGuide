//
//  LocationSearchField.swift
//  ParentGuide
//

import MapKit
import SwiftUI

/// A text field with Apple Maps autocomplete suggestions for location input.
struct LocationSearchField: View {
    let placeholder: String
    @Binding var text: String
    var onLocationSelected: ((MKLocalSearchCompletion) -> Void)?

    @State private var completer = LocationCompleter()
    @State private var isShowingSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    completer.search(query: newValue)
                    isShowingSuggestions = isFocused && !newValue.isEmpty
                }
                .onChange(of: isFocused) { _, focused in
                    isShowingSuggestions = focused && !text.isEmpty && !completer.results.isEmpty
                }

            if isShowingSuggestions && !completer.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.results.prefix(5), id: \.self) { result in
                        Button {
                            text = result.title
                            onLocationSelected?(result)
                            isShowingSuggestions = false
                            isFocused = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if result != completer.results.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Location Completer

@Observable
private class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently handle — autocomplete is best-effort
        NSLog("[LocationCompleter] Error: %@", error.localizedDescription)
    }
}

// MARK: - Helper to resolve a completion to full details

extension MKLocalSearchCompletion {
    /// Resolves this completion into a full map item with coordinates, address, etc.
    func resolve() async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: self)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            NSLog("[LocationSearch] Resolve error: %@", error.localizedDescription)
            return nil
        }
    }
}
