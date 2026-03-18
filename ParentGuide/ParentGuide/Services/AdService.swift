//
//  AdService.swift
//  ParentGuide
//

import Foundation
import GoogleMobileAds

@Observable
class AdService {
    static let shared = AdService()

    // MARK: - Ad Unit IDs
    // App ID: ca-app-pub-7551087457561398~1395618622
    // (configured in Info.plist under GADApplicationIdentifier)

    enum AdUnitID {
        // Real IDs — swap back before App Store submission:
        // static let banner = "ca-app-pub-7551087457561398/1877635245"
        // static let interstitial = "ca-app-pub-7551087457561398/6917340369"

        // Google test IDs for simulator/development
        static let banner = "ca-app-pub-3940256099942544/2435281174"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    }

    // MARK: - State
    private(set) var interstitialAd: InterstitialAd?
    private(set) var isLoadingInterstitial = false

    /// Whether ads should be shown (non-subscribers and non-admins only).
    var isAdEnabled: Bool {
        !SubscriptionService.shared.hasFullAccess
    }

    // MARK: - Init
    private init() {}

    // MARK: - Banner
    var bannerAdUnitID: String {
        AdUnitID.banner
    }

    // MARK: - Interstitial
    func loadInterstitial() async {
        guard !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        do {
            interstitialAd = try await InterstitialAd.load(
                with: AdUnitID.interstitial,
                request: Request()
            )
            print("[AdService] Interstitial loaded")
        } catch {
            print("[AdService] Interstitial failed: \(error.localizedDescription)")
            interstitialAd = nil
        }
        isLoadingInterstitial = false
    }

    func showInterstitial(from viewController: UIViewController) {
        guard let ad = interstitialAd else {
            print("[AdService] Interstitial not ready")
            Task { await loadInterstitial() }
            return
        }
        ad.present(from: viewController)
        interstitialAd = nil
        Task { await loadInterstitial() }
    }
}
