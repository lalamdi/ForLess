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

import SwiftUI

// MARK: - Checkout screen

struct CheckoutView: View {
    let deal: Deal          // the deal being ordered
    let storeName: String   // shown under the item name

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var data = DataStore()

    @State private var quantity = 1
    @State private var payment: PaymentMethod = .applePay
    @State private var notes = ""
    @State private var isPlacing = false
    @State private var errorMessage: String?
    @State private var placed: PlacedOrder?   // set after saving; opens the confirmation screen

    private let methods: [PaymentMethod] = [.applePay, .card, .payAtPickup]

    // Price calculations based on the chosen quantity
    private var total: Double { deal.dealPrice * Double(quantity) }
    private var originalTotal: Double { deal.originalPrice * Double(quantity) }
    private var saving: Double { originalTotal - total }
    private var soldOut: Bool { deal.quantityLeft < 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard

                // Payment options
                Text("Payment method")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.ink)
                ForEach(methods, id: \.self) { method in
                    paymentRow(method)
                }

                // Optional notes (allergies, requests) sent to the restaurant
                Text("Notes for the restaurant (optional)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.ink)
                TextField("Allergies or requests, e.g. no nuts, no onions", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 15))
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line))

                // How much the customer saves and how much food is rescued
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill").foregroundStyle(Color.brand)
                    Text("You're saving \(qar(saving)) and rescuing \(quantity) \(quantity == 1 ? "meal" : "meals") from waste.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandDark)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 14))

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
        // Pay button stays at the bottom of the screen
        .safeAreaInset(edge: .bottom) {
            Button {
                placeOrder()
            } label: {
                if isPlacing {
                    ProgressView().tint(.white)
                } else if soldOut {
                    Text("Sold out")
                } else {
                    Label(payment == .payAtPickup ? "Place order · \(qar(total))" : "Pay \(qar(total))",
                          systemImage: "lock.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPlacing || soldOut)
            .opacity(soldOut ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }
        // After the order is saved, show the confirmation screen.
        // When it closes, go back to the home screen.
        .fullScreenCover(item: $placed, onDismiss: { dismiss() }) { placed in
            OrderConfirmationView(orderId: placed.id, order: placed.order, deal: deal, storeName: storeName)
        }
    }

    // MARK: - Pieces of the screen

    /// Item, quantity stepper and price breakdown.
    private var summaryCard: some View {
        VStack(spacing: 12) {
            // Item row
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandLight)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "fork.knife").foregroundStyle(Color.brand))
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
                    Text(qar(deal.originalPrice))   // crossed-out original price
                        .font(.system(size: 12))
                        .strikethrough()
                        .foregroundStyle(Color.muted)
                }
            }

            // Quantity stepper (limited to how many are left)
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
                    stepButton("minus", enabled: quantity > 1) { quantity -= 1 }
                    Text("\(quantity)")
                        .font(.system(size: 16, weight: .bold))
                        .frame(minWidth: 20)
                    stepButton("plus", enabled: quantity < max(1, deal.quantityLeft)) { quantity += 1 }
                }
            }

            // Price breakdown
            Divider()
            line("Original price", qar(originalTotal))
            line("Discount", "− \(qar(saving))", valueColor: Color.brandText)
            line("Service fee", "Free")
            Divider()
            HStack {
                Text("Total").font(.system(size: 17, weight: .bold))
                Spacer()
                Text(qar(total)).font(.system(size: 17, weight: .heavy))
            }
            .foregroundStyle(Color.ink)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    /// One payment option; the selected one has an orange border and filled circle.
    private func paymentRow(_ method: PaymentMethod) -> some View {
        let selected = payment == method
        return Button { payment = method } label: {
            HStack(spacing: 12) {
                Image(systemName: method.icon)
                    .frame(width: 40, height: 40)
                    .background(selected ? Color.brandLight : Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(selected ? Color.brand : Color.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ink)
                    Text(method.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Color.brand : Color.line)
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? Color.brand : Color.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    /// The − and + buttons of the quantity stepper.
    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(icon == "plus" ? Color.brand : Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(icon == "plus" ? Color.white : Color.ink)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    /// One row of the price breakdown (label on the left, value on the right).
    private func line(_ label: String, _ value: String, valueColor: Color = .muted) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.muted)
            Spacer()
            Text(value).foregroundStyle(valueColor).fontWeight(.semibold)
        }
        .font(.system(size: 14))
    }

    // MARK: - Save the order to Firestore

    /// Builds the order, saves it in the "orders" collection, lowers the
    /// deal's quantity, and opens the confirmation screen.
    private func placeOrder() {
        errorMessage = nil
        guard let uid = auth.uid, let dealId = deal.id else {
            errorMessage = "Please sign in again."
            return
        }
        isPlacing = true
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let order = Order(
            id: nil,
            customerId: uid,
            storeId: deal.storeId,
            items: [OrderItem(dealId: dealId, title: deal.title, quantity: quantity, price: deal.dealPrice)],
            total: total,
            paymentMethod: payment,
            status: .new,                                                   // business sees it as a new order
            pickupCode: String(format: "%04d", Int.random(in: 0...9999)),  // random 4-digit pickup code
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            createdAt: Date()
        )
        do {
            let orderId = try data.createOrder(order)
            data.reduceQuantity(dealId: dealId, by: quantity)
            placed = PlacedOrder(id: orderId, order: order)
        } catch {
            errorMessage = error.localizedDescription
        }
        isPlacing = false
    }
}

// MARK: - Helpers

/// A saved order together with its Firestore ID (used to open the confirmation screen).
struct PlacedOrder: Identifiable {
    let id: String
    let order: Order
}

/// Formats a price, e.g. qar(20) -> "QAR 20".
func qar(_ amount: Double) -> String {
    "QAR " + amount.formatted(.number.precision(.fractionLength(0...2)))
}

/// Text and icons shown for each payment method.
extension PaymentMethod {
    var title: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Credit / Debit card"
        case .payAtPickup: return "Pay at pickup"
        }
    }
    var subtitle: String {
        switch self {
        case .applePay: return "Fast and secure"
        case .card: return "Visa •••• 4821"
        case .payAtPickup: return "Cash or card at the store"
        }
    }
    var icon: String {
        switch self {
        case .applePay: return "apple.logo"
        case .card: return "creditcard"
        case .payAtPickup: return "banknote"
        }
    }
}

// MARK: - Confirmation screen

/// Shown after the order is saved: order number, pickup code and pickup details.
struct OrderConfirmationView: View {
    let orderId: String
    let order: Order
    let deal: Deal
    let storeName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            // Orange check mark
            ZStack {
                Circle().fill(Color.brandLight).frame(width: 120, height: 120)
                Circle().fill(Color.brand).frame(width: 84, height: 84)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Order placed!")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color.ink)
            // Short order number made from the first 6 characters of the Firestore ID
            Text("Order #\(orderId.prefix(6).uppercased()) · \(storeName)")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)

            // Pickup code the customer shows at the store
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
            .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 20))

            // Pickup time, item, payment and note
            VStack(spacing: 10) {
                info("Pickup", "Today, \(deal.pickupStart.formatted(date: .omitted, time: .shortened)) – \(deal.pickupEnd.formatted(date: .omitted, time: .shortened))")
                info("Item", "\(deal.title) × \(order.items.first?.quantity ?? 1)")
                info(order.paymentMethod == .payAtPickup ? "Pay at pickup" : "Paid", "\(qar(order.total)) · \(order.paymentMethod.title)")
                if let notes = order.notes {
                    info("Your note", notes)
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

            Spacer()
            Button("Back to home") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(Color.appBackground)
    }

    /// One row of details (label on the left, value on the right).
    private func info(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Color.muted)
            Spacer()
            Text(value)
                .foregroundStyle(Color.ink)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 14))
    }
}
