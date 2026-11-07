//
//  CheckoutView.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Checkout screen: item, quantity, price summary, payment method,
//  notes for the restaurant. "Pay" saves the order in Firestore,
//  lowers the deal's quantity, and opens the Order Confirmation screen.
//
//
import SwiftUI

// MARK: - Checkout screen

struct CheckoutView: View {

    let deal: Deal
    let storeName: String

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var data = DataStore()

    @State private var quantity: Int
    @State private var payment: PaymentMethod = .applePay
    @State private var notes = ""
    @State private var isPlacing = false
    @State private var errorMessage: String?
    @State private var placed: PlacedOrder?

    private let methods: [PaymentMethod] = [
        .applePay, .card, .payAtPickup
    ]

    init(
        deal: Deal,
        storeName: String,
        initialQuantity: Int = 1
    ) {
        self.deal = deal
        self.storeName = storeName

        _quantity = State(
            initialValue: min(
                max(1, initialQuantity),
                max(1, deal.quantityLeft)
            )
        )
    }

    // MARK: - Price calculations

    private var total: Double {
        deal.dealPrice * Double(quantity)
    }

    private var originalTotal: Double {
        deal.originalPrice * Double(quantity)
    }

    private var saving: Double {
        originalTotal - total
    }

    private var soldOut: Bool {
        deal.quantityLeft < 1
    }

    // MARK: - Main screen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                summaryCard

                Text("Payment method")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.ink)

                ForEach(methods, id: \.self) { method in
                    paymentRow(method)
                }

                Text("Notes for the restaurant (optional)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.ink)

                TextField(
                    "Allergies or requests, e.g. no nuts, no onions",
                    text: $notes,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .font(.system(size: 15))
                .padding(14)
                .background(
                    Color.white,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.line)
                )

                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.brand)

                    Text(
                        "You're saving \(qar(saving)) and rescuing \(quantity) \(quantity == 1 ? "meal" : "meals") from waste."
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandDark)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.brandLight,
                    in: RoundedRectangle(cornerRadius: 14)
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)

        .safeAreaInset(edge: .bottom) {
            Button {
                placeOrder()
            } label: {
                if isPlacing {
                    ProgressView().tint(.white)
                } else if soldOut {
                    Text("Sold out")
                } else {
                    Label(
                        payment == .payAtPickup
                            ? "Place order · \(qar(total))"
                            : "Pay \(qar(total))",
                        systemImage: "lock.fill"
                    )
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPlacing || soldOut)
            .opacity(soldOut ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }

        // Opens the separate confirmation screen after saving.
        .fullScreenCover(
            item: $placed,
            onDismiss: {
                dismiss()
            }
        ) { placed in
            OrderConfirmationView(
                orderId: placed.id,
                order: placed.order,
                deal: deal,
                storeName: storeName
            )
        }
    }

    // MARK: - Order summary

    private var summaryCard: some View {
        VStack(spacing: 12) {

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandLight)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Color.brand)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(deal.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text(storeName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(qar(deal.dealPrice))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.brandText)

                    Text(qar(deal.originalPrice))
                        .font(.system(size: 12))
                        .strikethrough()
                        .foregroundStyle(Color.muted)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quantity")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text("\(deal.quantityLeft) left")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }

                Spacer()

                HStack(spacing: 14) {
                    stepButton("minus", enabled: quantity > 1) {
                        quantity -= 1
                    }

                    Text("\(quantity)")
                        .font(.system(size: 16, weight: .bold))
                        .frame(minWidth: 20)

                    stepButton(
                        "plus",
                        enabled: quantity < max(1, deal.quantityLeft)
                    ) {
                        quantity += 1
                    }
                }
            }

            Divider()

            line("Original price", qar(originalTotal))
            line(
                "Discount",
                "− \(qar(saving))",
                valueColor: Color.brandText
            )
            line("Service fee", "Free")

            Divider()

            HStack {
                Text("Total")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Text(qar(total))
                    .font(.system(size: 17, weight: .heavy))
            }
            .foregroundStyle(Color.ink)
        }
        .padding(16)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Payment options

    private func paymentRow(_ method: PaymentMethod) -> some View {
        let selected = payment == method

        return Button {
            payment = method
        } label: {
            HStack(spacing: 12) {
                Image(systemName: method.icon)
                    .frame(width: 40, height: 40)
                    .background(
                        selected ? Color.brandLight : Color.appBackground,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(
                        selected ? Color.brand : Color.ink
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text(method.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }

                Spacer()

                Image(
                    systemName: selected
                        ? "largecircle.fill.circle"
                        : "circle"
                )
                .font(.system(size: 22))
                .foregroundStyle(
                    selected ? Color.brand : Color.line
                )
            }
            .padding(12)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selected ? Color.brand : Color.line,
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quantity buttons

    private func stepButton(
        _ icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(
                    icon == "plus" ? Color.brand : Color.appBackground,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .foregroundStyle(
                    icon == "plus" ? Color.white : Color.ink
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    // MARK: - Price row

    private func line(
        _ label: String,
        _ value: String,
        valueColor: Color = .muted
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.muted)

            Spacer()

            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(.semibold)
        }
        .font(.system(size: 14))
    }

    // MARK: - Place order

    private func placeOrder() {
        errorMessage = nil

        guard let uid = auth.uid,
              let dealId = deal.id else {
            errorMessage = "Please sign in again."
            return
        }

        isPlacing = true

        let trimmedNotes = notes.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let order = Order(
            id: nil,
            customerId: uid,
            storeId: deal.storeId,
            items: [
                OrderItem(
                    dealId: dealId,
                    title: deal.title,
                    quantity: quantity,
                    price: deal.dealPrice
                )
            ],
            total: total,
            paymentMethod: payment,
            status: .new,
            pickupCode: String(
                format: "%04d",
                Int.random(in: 0...9999)
            ),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            createdAt: Date()
        )

        do {
            let orderId = try data.createOrder(order)

            data.reduceQuantity(
                dealId: dealId,
                by: quantity
            )

            placed = PlacedOrder(
                id: orderId,
                order: order
            )

        } catch {
            errorMessage = error.localizedDescription
        }

        isPlacing = false
    }
}

// MARK: - Helpers

struct PlacedOrder: Identifiable {
    let id: String
    let order: Order
}

func qar(_ amount: Double) -> String {
    "QAR " + amount.formatted(
        .number.precision(.fractionLength(0...2))
    )
}

extension PaymentMethod {

    var title: String {
        switch self {
        case .applePay:
            return "Apple Pay"
        case .card:
            return "Credit / Debit card"
        case .payAtPickup:
            return "Pay at pickup"
        }
    }

    var subtitle: String {
        switch self {
        case .applePay:
            return "Fast and secure"
        case .card:
            return "Visa •••• 4821"
        case .payAtPickup:
            return "Cash or card at the store"
        }
    }

    var icon: String {
        switch self {
        case .applePay:
            return "apple.logo"
        case .card:
            return "creditcard"
        case .payAtPickup:
            return "banknote"
        }
    }
}
