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

    let storeName: String
    var onLinesChange: (([CartLine]) -> Void)? = nil   // keeps the cart in sync
    var onPlaced: (() -> Void)? = nil                  // clears the cart after paying

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.switchTab) private var switchTab

    @StateObject private var data = DataStore()

    @State private var lines: [CartLine]
    @State private var payment: PaymentMethod = .applePay
    @State private var notes = ""
    @State private var isPlacing = false
    @State private var errorMessage: String?
    @State private var placed: PlacedOrder?

    private let methods: [PaymentMethod] = [
        .applePay, .card, .payAtPickup
    ]

    /// One deal ("Buy again" and similar).
    init(
        deal: Deal,
        storeName: String,
        initialQuantity: Int = 1
    ) {
        self.init(
            lines: [CartLine(
                deal: deal,
                quantity: min(max(1, initialQuantity), max(1, deal.quantityLeft))
            )],
            storeName: storeName
        )
    }

    /// Several deals (the cart).
    init(
        lines: [CartLine],
        storeName: String,
        onLinesChange: (([CartLine]) -> Void)? = nil,
        onPlaced: (() -> Void)? = nil
    ) {
        self.storeName = storeName
        self.onLinesChange = onLinesChange
        self.onPlaced = onPlaced
        _lines = State(initialValue: lines)
    }

    // MARK: - Price calculations

    private var quantity: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }

    private var total: Double {
        lines.reduce(0) { $0 + $1.deal.dealPrice * Double($1.quantity) }
    }

    private var originalTotal: Double {
        lines.reduce(0) { $0 + $1.deal.originalPrice * Double($1.quantity) }
    }

    private var saving: Double {
        originalTotal - total
    }

    private var soldOut: Bool {
        lines.isEmpty || lines.contains { $0.deal.quantityLeft < 1 }
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
        .hideKeyboardOnTap()
        .background(Color.appBackground)
        .navigationTitle(onLinesChange == nil ? "Checkout" : "Your cart")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: lines) { _, newLines in
            onLinesChange?(newLines)
        }

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
                switchTab(0)      // "Back to home" goes to the Home tab
                onPlaced?()
            }
        ) { placed in
            // One page: "Order placed!" and the live tracking
            NavigationStack {
                OrderTrackingView(
                    order: placed.trackedOrder,
                    storeName: storeName,
                    storeAddress: "",
                    isNewOrder: true,
                    savedAmount: placed.saved,
                    onBackToHome: { self.placed = nil }
                )
            }
        }
    }

    // MARK: - Order summary

    private var summaryCard: some View {
        VStack(spacing: 12) {

            ForEach(lines) { item in
                lineRow(item)
                Divider()
            }

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

    // MARK: - One item in the order

    private func lineRow(_ item: CartLine) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandLight)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: item.deal.kind == .grocery ? "basket" : "fork.knife")
                            .foregroundStyle(Color.brand)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.deal.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text(storeName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(qar(item.deal.dealPrice))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.brandText)

                    Text(qar(item.deal.originalPrice))
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

                    Text("\(item.deal.quantityLeft) left")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }

                Spacer()

                // Remove (cart only)
                if onLinesChange != nil {
                    Button {
                        remove(item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.muted)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove from cart")
                }

                HStack(spacing: 14) {
                    stepButton("minus", enabled: item.quantity > 1) {
                        changeQuantity(item, by: -1)
                    }

                    Text("\(item.quantity)")
                        .font(.system(size: 16, weight: .bold))
                        .frame(minWidth: 20)

                    stepButton(
                        "plus",
                        enabled: item.quantity < max(1, item.deal.quantityLeft)
                    ) {
                        changeQuantity(item, by: 1)
                    }
                }
            }
        }
    }

    private func changeQuantity(_ item: CartLine, by amount: Int) {
        guard let index = lines.firstIndex(where: { $0.id == item.id }) else { return }
        lines[index].quantity += amount
    }

    private func remove(_ item: CartLine) {
        lines.removeAll { $0.id == item.id }
        if lines.isEmpty { dismiss() }
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
              let storeId = lines.first?.deal.storeId,
              !lines.contains(where: { $0.deal.id == nil }) else {
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
            storeId: storeId,
            items: lines.map { item in
                OrderItem(
                    dealId: item.deal.id ?? "",
                    title: item.deal.title,
                    quantity: item.quantity,
                    price: item.deal.dealPrice
                )
            },
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

            for item in lines {
                data.reduceQuantity(
                    dealId: item.deal.id ?? "",
                    by: item.quantity
                )
            }

            placed = PlacedOrder(
                id: orderId,
                order: order,
                saved: saving
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
    let saved: Double      // how much the customer saved on this order

    /// The order with its Firestore id (the tracking screen needs it).
    var trackedOrder: Order {
        var tracked = order
        tracked.id = id
        return tracked
    }
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
