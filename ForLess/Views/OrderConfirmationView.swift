//
//
//  OrderConfirmationView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//

import SwiftUI

struct OrderConfirmationView: View {

    let orderId: String
    let order: Order
    let deal: Deal
    let storeName: String

    @Environment(\.dismiss) private var dismiss

    private var quantity: Int {
        order.items.first?.quantity ?? 1
    }

    private var totalSaved: Double {
        (deal.originalPrice - deal.dealPrice) * Double(quantity)
    }

    private var pickupTime: String {
        "\(deal.pickupStart.formatted(date: .omitted, time: .shortened)) – \(deal.pickupEnd.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.brandLight)
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(Color.brand)
                        .frame(width: 84, height: 84)

                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Thank you message
                VStack(spacing: 8) {
                    Text("Order placed!")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.ink)

                    Text("Order #\(orderId.prefix(6).uppercased()) · \(storeName)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                }

                // Pickup code
                VStack(spacing: 6) {
                    Text("Your pickup code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandDark)

                    Text(order.pickupCode)
                        .font(.system(size: 44, weight: .heavy))
                        .kerning(8)
                        .foregroundStyle(Color.brandDark)

                    Text("Show this code at the counter")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.brandDark)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    Color.brandLight,
                    in: RoundedRectangle(cornerRadius: 20)
                )

                // Savings and food rescued
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brand)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("You rescued food!")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ink)

                        Text("You saved \(qar(totalSaved)) and rescued \(quantity) \(quantity == 1 ? "item" : "items") from waste.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.muted)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    Color.brandLight,
                    in: RoundedRectangle(cornerRadius: 14)
                )

                // Order details
                VStack(spacing: 12) {
                    info(
                        "Pickup date",
                        deal.pickupStart.formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                    )

                    info("Pickup time", pickupTime)

                    info(
                        "Item",
                        "\(deal.title) × \(quantity)"
                    )

                    info(
                        order.paymentMethod == .payAtPickup
                            ? "Payment"
                            : "Paid",
                        "\(qar(order.total)) · \(order.paymentMethod.title)"
                    )

                    if let notes = order.notes, !notes.isEmpty {
                        info("Your note", notes)
                    }
                }
                .padding(16)
                .background(
                    Color.white,
                    in: RoundedRectangle(cornerRadius: 18)
                )

            }
            .padding(24)
        }
        .background(Color.appBackground)
        // "Back to home" stays visible at the bottom, even on small iPhones
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Back to home")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.appBackground)
        }
    }

    // MARK: - Information row

    private func info(
        _ label: String,
        _ value: String
    ) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(Color.muted)

            Spacer()

            Text(value)
                .foregroundStyle(Color.ink)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 14))
    }
}
