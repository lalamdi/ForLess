//
//  OrdersView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//

//  Customer "My Orders" screen (Order history).
//  Shows how many orders the customer made and how much they saved,
//  filter chips (All, Restaurants, Groceries), and the orders grouped into
//  "This week" and "Earlier". Tapping an order opens its live tracking.
//
 
import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var data = DataStore()

    @State private var orders: [Order] = []
    @State private var filter: OrderFilter = .all
    @State private var isLoading = true

    // True when opened from Profile > Order history (it has a back button)
    var isPushed = false

    // MARK: - Filters

    enum OrderFilter: String, CaseIterable {
        case all = "All"
        case restaurants = "Restaurants"
        case groceries = "Groceries"
    }

    // MARK: - Data

    private var countedOrders: [Order] {
        orders.filter { $0.status != .cancelled }
    }

    private func saved(for order: Order) -> Double {
        order.items.reduce(0) { total, item in
            guard let deal = data.deals.first(where: {
                $0.id == item.dealId
            }) else {
                return total
            }

            return total + max(0, deal.originalPrice - item.price)
                * Double(item.quantity)
        }
    }

    private var totalSaved: Double {
        countedOrders.reduce(0) {
            $0 + saved(for: $1)
        }
    }

    private func storeType(of order: Order) -> StoreType? {
        data.stores.first {
            $0.id == order.storeId
        }?.type
    }

    private func storeName(of order: Order) -> String {
        data.stores.first {
            $0.id == order.storeId
        }?.name ?? "Store"
    }

    private var filteredOrders: [Order] {
        orders.filter { order in
            switch filter {
            case .all:
                return true
            case .restaurants:
                return storeType(of: order) == .restaurant
            case .groceries:
                return storeType(of: order) == .grocery
            }
        }
    }

    private var weekAgo: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: Date()
        ) ?? Date.distantPast
    }

    private var thisWeekOrders: [Order] {
        filteredOrders.filter { $0.createdAt >= weekAgo }
    }

    private var earlierOrders: [Order] {
        filteredOrders.filter { $0.createdAt < weekAgo }
    }

    // MARK: - Screen

    var body: some View {
        if isPushed {
            screen
        } else {
            NavigationStack { screen }
        }
    }

    private var screen: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !isPushed {
                        Text("My Orders")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(Color.ink)
                    }

                    summaryBanner
                    filterChips

                    if let error = data.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)

                    } else if filteredOrders.isEmpty {
                        Text(
                            orders.isEmpty
                            ? "No orders yet. Your orders will show here."
                            : "No orders in this category."
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                    }

                    if !thisWeekOrders.isEmpty {
                        section("THIS WEEK", orders: thisWeekOrders)
                    }

                    if !earlierOrders.isEmpty {
                        section("EARLIER", orders: earlierOrders)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .toolbar(isPushed ? .visible : .hidden, for: .navigationBar)
            .navigationTitle(isPushed ? "Order history" : "")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await reload()
                }
            }
            .refreshable {
                await reload()
            }
        }
    }

    // MARK: - Loading

    private func reload() async {
        await data.loadAll()

        if let uid = auth.uid {
            orders = (try? await data.fetchOrders(customerId: uid)) ?? []
        }

        isLoading = false
    }

    // MARK: - Summary banner

    private var summaryBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf")
                .foregroundStyle(Color.brand)

            Text(
                "\(countedOrders.count) \(countedOrders.count == 1 ? "order" : "orders") · \(qar(totalSaved)) saved so far"
            )
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.brandDark)

            Spacer()
        }
        .padding(14)
        .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(OrderFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .foregroundStyle(
                            filter == option ? Color.white : Color.ink
                        )
                        .background(
                            filter == option ? Color.ink : Color.white,
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    filter == option ? Color.clear : Color.line
                                )
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Order sections

    private func section(_ title: String, orders: [Order]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.muted)

            ForEach(orders) { order in
                orderCard(order)
            }
        }
    }

    // MARK: - Order card

    private func orderCard(_ order: Order) -> some View {
        let firstItem = order.items.first
        let deal = data.deals.first {
            $0.id == firstItem?.dealId
        }
        let extraItems = order.items.count - 1
        let originalTotal = order.total + saved(for: order)

        return HStack(spacing: 12) {

            // Tapping the order opens its live tracking screen.
            NavigationLink {
                OrderTrackingView(
                    order: order,
                    storeName: storeName(of: order),
                    storeAddress: data.stores.first {
                        $0.id == order.storeId
                    }?.address ?? "Address unavailable"
                )
            } label: {
                HStack(spacing: 12) {
                    orderImage(deal)
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(firstItem?.title ?? "Order")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)

                        Text(
                            extraItems > 0
                            ? "\(storeName(of: order)) · \(dateText(order.createdAt)) · +\(extraItems) more"
                            : "\(storeName(of: order)) · \(dateText(order.createdAt))"
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                        .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(qar(order.total))
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Color.brandText)

                            if originalTotal > order.total {
                                Text(qar(originalTotal))
                                    .font(.system(size: 11))
                                    .strikethrough()
                                    .foregroundStyle(Color.muted)
                            }
                        }

                        statusLabel(order.status)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Status label

    @ViewBuilder
    private func statusLabel(_ status: OrderStatus) -> some View {
        switch status {
        case .pickedUp:
            Label("Picked up", systemImage: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandText)

        case .cancelled:
            Label("Cancelled", systemImage: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.muted)

        case .new:
            Label("Order placed", systemImage: "clock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandText)

        case .preparing:
            Label("Preparing", systemImage: "clock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandText)

        case .ready:
            Label("Ready for pickup", systemImage: "bag")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandText)
        }
    }

    // MARK: - Date

    private func dateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        if date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }

        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Order image

    @ViewBuilder
    private func orderImage(_ deal: Deal?) -> some View {
        if let urlString = deal?.photoURL,
           let url = URL(string: urlString) {

            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brandLight
            }

        } else {
            Color.brandLight
                .overlay {
                    Image(
                        systemName: deal?.kind == .grocery
                        ? "bag"
                        : "fork.knife"
                    )
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brand)
                }
        }
    }
}
