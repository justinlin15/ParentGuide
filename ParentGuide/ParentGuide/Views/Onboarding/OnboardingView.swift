//
//  OnboardingView.swift
//  ParentGuide
//

import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @State private var metroService = MetroService.shared
    @State private var selectedMetro: AppConstants.Metro?
    @State private var isDetecting = false
    @State private var locationManager = CLLocationManager()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App branding
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandBlue)

            Text("Welcome to Parent Guide!")
                .font(.system(.title, design: .rounded, weight: .bold))

            Text("Choose your metro area to see\nevents and guides near you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Auto-detect button
            Button {
                isDetecting = true
                Task {
                    let detected = await metroService.autoDetect()
                    selectedMetro = detected
                    isDetecting = false
                }
            } label: {
                Label(
                    isDetecting ? "Detecting..." : "Use My Location",
                    systemImage: "location.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandBlue)
                .clipShape(Capsule())
            }
            .disabled(isDetecting)
            .padding(.horizontal, 32)

            // Divider
            HStack {
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                Text("or pick a metro area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle().fill(Color(.systemGray4)).frame(height: 1)
            }
            .padding(.horizontal, 32)

            // Metro list
            VStack(spacing: 8) {
                ForEach(AppConstants.launchMetros, id: \.id) { metro in
                    Button {
                        selectedMetro = metro
                    } label: {
                        HStack {
                            Text(metro.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedMetro?.id == metro.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.brandBlue)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            selectedMetro?.id == metro.id
                                ? Color.brandPink.opacity(0.3)
                                : Color(.systemGray6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Get Started button
            Button {
                if let metro = selectedMetro {
                    metroService.completeOnboarding(with: metro)
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedMetro != nil ? Color.brandBlue : Color.gray)
                    .clipShape(Capsule())
            }
            .disabled(selectedMetro == nil)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .onAppear {
            // Immediately request location permission on first launch
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
}

#Preview {
    OnboardingView()
}
