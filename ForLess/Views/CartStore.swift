//
//  CartStore.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  The customer's cart. It holds deals from ONE store at a time.
//  "Add to cart" on Deal details fills it, and the orange "View cart" bar
//  (shown on Home and on the store page) opens it in the Checkout screen.
//

import SwiftUI
import Combine

// One deal in the cart with how many the customer wants
struct CartLine: Identifiable, Equatable {
    let deal: Deal
    var quantity: Int

    var id: String { deal.id ?? deal.title }

    static func == (a: CartLine, b: CartLine) -> Bool {
        a.id == b.id && a.quantity == b.quantity
    }
}

final class CartStore: ObservableObject {
    @Published var lines: [CartLine] = []
    @Published var storeName = ""
    @Published var homeResetID = UUID()   // changes to send Home back to its first screen

    var itemCount: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }

    var total: Double {
        lines.reduce(0) { $0 + $1.deal.dealPrice * Double($1.quantity) }
    }

    /// True if the cart already has items from a different store.
    func isOtherStore(_ deal: Deal) -> Bool {
        guard let first = lines.first else { return false }
        return first.deal.storeId != deal.storeId
    }

    /// Adds a deal. If it is already in the cart, the quantity goes up.
    func add(_ deal: Deal, storeName: String, quantity: Int) {
        let maxQuantity = max(1, deal.quantityLeft)
        if let index = lines.firstIndex(where: { $0.id == (deal.id ?? deal.title) }) {
            lines[index].quantity = min(lines[index].quantity + quantity, maxQuantity)
        } else {
            lines.append(CartLine(deal: deal, quantity: min(quantity, maxQuantity)))
        }
        self.storeName = storeName
    }

    /// Used by the Checkout screen when the customer changes or removes items.
    func setLines(_ newLines: [CartLine]) {
        lines = newLines
        if newLines.isEmpty { storeName = "" }
    }

    /// Brings Home back to its first screen (used after an order is placed).
    func goHome() {
        homeResetID = UUID()
    }

    func clear() {
        lines = []
        storeName = ""
    }
}

// MARK: - "View cart" bar

struct CartBar: View {
    @EnvironmentObject private var cart: CartStore

    var body: some View {
        if !cart.lines.isEmpty {
            NavigationLink {
                CheckoutView(
                    lines: cart.lines,
                    storeName: cart.storeName,
                    onLinesChange: { cart.setLines($0) },
                    onPlaced: {
                        cart.clear()
                        cart.goHome()
                    }
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bag.fill")
                    Text("View cart · \(cart.itemCount) \(cart.itemCount == 1 ? "item" : "items")")
                    Spacer()
                    Text(qar(cart.total))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .background(Color.brand, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}
