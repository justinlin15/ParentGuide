//
//  SubscriptionPlan.swift
//  ParentGuide
//

import Foundation

struct SubscriptionPlan: Identifiable {
    let id: String
    let productID: String
    let name: String
    let price: String
    let period: String
    let features: [String]
    let isBestValue: Bool

    static let monthly = SubscriptionPlan(
        id: "monthly",
        productID: SubscriptionService.monthlyID,
        name: "Monthly Membership",
        price: "$5",
        period: "Every month",
        features: ["View all upcoming events", "Calendar sync", "Ad-free experience"],
        isBestValue: false
    )

    static let annual = SubscriptionPlan(
        id: "annual",
        productID: SubscriptionService.annualID,
        name: "Annual Membership",
        price: "$48",
        period: "Every year — save 20%",
        features: ["View all upcoming events", "Calendar sync", "Ad-free experience"],
        isBestValue: true
    )

    static let allPlans: [SubscriptionPlan] = [.monthly, .annual]
}
