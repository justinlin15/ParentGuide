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
    let trialDays: Int
    let features: [String]
    let isBestValue: Bool

    static let monthly = SubscriptionPlan(
        id: "monthly",
        productID: SubscriptionService.monthlyID,
        name: "Monthly Membership",
        price: "$4",
        period: "Every month",
        trialDays: 7,
        features: ["1,500+ monthly events", "Subscriber meet-ups", "Local partner discounts"],
        isBestValue: false
    )

    static let annual = SubscriptionPlan(
        id: "annual",
        productID: SubscriptionService.annualID,
        name: "Annual Membership",
        price: "$45",
        period: "Every year",
        trialDays: 7,
        features: ["1,500+ monthly events", "Subscriber meet-ups", "Local partner discounts"],
        isBestValue: true
    )

    static let allPlans: [SubscriptionPlan] = [.monthly, .annual]
}
