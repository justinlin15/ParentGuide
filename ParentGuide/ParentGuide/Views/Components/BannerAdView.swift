//
//  BannerAdView.swift
//  ParentGuide
//

import GoogleMobileAds
import SwiftUI

struct BannerAdView: View {
    var adUnitID: String

    var body: some View {
        if AdService.shared.isAdEnabled {
            BannerAdRepresentable(adUnitID: adUnitID)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

#Preview {
    BannerAdView(adUnitID: "test")
}
