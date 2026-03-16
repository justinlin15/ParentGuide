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

                    private enum AdUnitID {
                            static let banner       = "ca-app-pub-7551087457561398/1877635245"
                                    static let interstitial = "ca-app-pub-7551087457561398/6917340369"
                                        }

                                            // MARK: - State
                                                private(set) var interstitialAd: GADInterstitialAd?
                                                    private(set) var isLoadingInterstitial = false

                                                        // MARK: - Init
                                                            private init() {
                                                                    // SDK is initialized in App entry point via GADMobileAds.sharedInstance().start()
                                                                        }

                                                                            // MARK: - Banner
                                                                                /// Returns the real banner ad unit ID.
                                                                                    var bannerAdUnitID: String {
                                                                                            AdUnitID.banner
                                                                                                }

                                                                                                    // MARK: - Interstitial
                                                                                                        func loadInterstitial() async {
                                                                                                                guard !isLoadingInterstitial else { return }
                                                                                                                        isLoadingInterstitial = true
                                                                                                                                do {
                                                                                                                                            interstitialAd = try await GADInterstitialAd.load(
                                                                                                                                                            withAdUnitID: AdUnitID.interstitial,
                                                                                                                                                                            request: GADRequest()
                                                                                                                                                                                        )
                                                                                                                                                                                                    print("[AdService] Interstitial loaded")
                                                                                                                                                                                                            } catch {
                                                                                                                                                                                                                        print("[AdService] Interstitial failed to load: \(error.localizedDescription)")
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
                                                                                                                                                                                                                                                                                                                        ad.present(fromRootViewController: viewController)
                                                                                                                                                                                                                                                                                                                                interstitialAd = nil
                                                                                                                                                                                                                                                                                                                                        Task { await loadInterstitial() }
                                                                                                                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                                                                                                            }
