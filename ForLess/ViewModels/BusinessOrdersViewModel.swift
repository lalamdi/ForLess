//
//  BusinessOrdersViewModel.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//

//  Business side: finds the store of the signed-in business user,
//  loads its orders, and changes an order's status
//  (new -> preparing -> ready -> pickedUp).
//  Used by BusinessOrdersView and BusinessOrderDetailView.
//

import Foundation
import Combine

/// Short order number shown on the business side, e.g. #FL-2041.
/// Sample orders already have IDs like FL-2041. New orders use the first 6 letters of the Firestore ID.
func orderNumber(for order: Order) -> String {
    let id = order.id ?? ""
    if id.hasPrefix("FL-") { return "#" + id }
    return "#" + String(id.prefix(6)).uppercased()
}

@MainActor
final class BusinessOrdersViewModel: ObservableObject {
    @Published var store: Store?                      // the store this business user owns
    @Published var orders: [Order] = []               // orders of that store, newest first
    @Published var customers: [String: User] = [:]    // customerId -> customer (for name and phone)
    @Published var deals: [String: Deal] = [:]        // dealId -> deal (for pickup time and photo)
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let data = DataStore()

    // MARK: - Loading

    /// Finds the store whose ownerId is this user's ID, then loads its orders.
    func load(ownerId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let ownedStore = try await data.fetchStore(ownerId: ownerId),
                  let storeId = ownedStore.id else {
                store = nil
                orders = []
                errorMessage = "No store is linked to this account yet. In Firestore, set the store's ownerId to your user ID."
                return
            }
            store = ownedStore

            let fetched = try await data.fetchOrders(storeId: storeId)
            orders = fetched

            // Get each customer and deal only once
            for customerId in Set(fetched.map { $0.customerId }) where customers[customerId] == nil {
                if let user = try? await data.fetchUser(uid: customerId) {
                    customers[customerId] = user
                }
            }
            for dealId in Set(fetched.compactMap { $0.items.first?.dealId }) where deals[dealId] == nil {
                if let deal = try? await data.fetchDeal(dealId: dealId) {
                    deals[dealId] = deal
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Changing an order

    /// Saves the new status in Firestore and updates the list on screen. Returns true if it worked.
    func setStatus(_ order: Order, to status: OrderStatus) async -> Bool {
        guard let id = order.id else { return false }
        do {
            try await data.updateOrderStatus(orderId: id, to: status)
            if let index = orders.firstIndex(where: { $0.id == id }) {
                orders[index].status = status
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers for the screens

    /// Orders that still need work (not picked up and not cancelled).
    var activeOrders: [Order] {
        orders.filter { $0.status == .new || $0.status == .preparing || $0.status == .ready }
    }

    /// How many orders have this status (shown on the filter buttons).
    func count(_ status: OrderStatus) -> Int {
        orders.filter { $0.status == status }.count
    }

    func customerName(for order: Order) -> String {
        customers[order.customerId]?.name ?? "Customer"
    }

    func customerPhone(for order: Order) -> String? {
        customers[order.customerId]?.phone
    }

    func deal(for order: Order) -> Deal? {
        guard let dealId = order.items.first?.dealId else { return nil }
        return deals[dealId]
    }

    /// Pickup time taken from the deal, e.g. "Pickup 5:00 PM - 7:00 PM".
    func pickupText(for order: Order) -> String {
        guard let deal = deal(for: order) else { return "Pickup time not set" }
        let start = deal.pickupStart.formatted(date: .omitted, time: .shortened)
        let end = deal.pickupEnd.formatted(date: .omitted, time: .shortened)
        return "Pickup \(start) - \(end)"
    }

    /// Meals and money from all picked-up orders (shown on the "Order picked up" screen).
    func pickedUpTotals() -> (meals: Int, earned: Double) {
        let finished = orders.filter { $0.status == .pickedUp }
        var meals = 0
        var earned = 0.0
        for order in finished {
            earned += order.total
            for item in order.items {
                meals += item.quantity
            }
        }
        return (meals, earned)
    }
}
