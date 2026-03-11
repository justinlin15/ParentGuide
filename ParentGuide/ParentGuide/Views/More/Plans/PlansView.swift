//
//  PlansView.swift
//  ParentGuide
//

import SwiftUI

struct PlansView: View {
    @State private var showComingSoon = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero text
                VStack(spacing: 12) {
                    Text("Unlimited family fun in")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Orange County")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandBlue)

                    Text("Become a member and access over 1,500 monthly events, exclusive subscriber meet-ups, local partner discounts and free giveaways!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Plan cards
                HStack(spacing: 16) {
                    ForEach(SubscriptionPlan.allPlans) { plan in
                        PlanCardView(plan: plan) {
                            showComingSoon = true
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Coming Soon!", isPresented: $showComingSoon) {
            Button("OK") {}
        } message: {
            Text("In-app subscriptions are coming soon. Stay tuned!")
        }
    }
}

struct PlanCardView: View {
    let plan: SubscriptionPlan
    var onSubscribe: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            if plan.isBestValue {
                Text("Best value")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .cornerRadius(4)
            }

            Text(plan.name)
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 2) {
                Text(plan.price)
                    .font(.system(size: 36, weight: .bold))
                Text(plan.period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(plan.trialDays) day free trial")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: onSubscribe) {
                Text("Start free trial")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandBlue)
                    .cornerRadius(20)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(feature)
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(plan.isBestValue ? Color.brandNavy : Color(.systemBackground))
        .foregroundStyle(plan.isBestValue ? .white : .primary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(plan.isBestValue ? Color.clear : Color(.systemGray4), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        PlansView()
    }
}
