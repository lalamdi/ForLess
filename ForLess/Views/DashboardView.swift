//
//  DashboardView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Business dashboard: today's overview with the number of new order
//  live deals and meals saved this week, the newest new orders
//  and the store's live deals.
//  "Add a surplus deal", "See all" and "Add new" switch to the other tabs.
//
 

import SwiftUI
 
struct DashboardView: View {
    @EnvironmentObject private var auth: AuthManager   // used for the user's ID and Sign out
    @StateObject private var model = BusinessOrdersViewModel()
    @StateObject private var data = DataStore()
    @State private var deals: [Deal] = []              // deals of this store
    @State private var showSignOutAlert = false        // confirm pop up for Sign out
 
    var onAddDeal: () -> Void      // opens the Add deal tab
    var onSeeOrders: () -> Void    // opens the Orders tab
 
    // MARK: - Numbers for the overview
 
    private var newOrders: [Order] {
        model.orders.filter { $0.status == .new }
    }
 
    /// Deals that still have items left.
    private var liveDeals: [Deal] {
        deals.filter { $0.quantityLeft > 0 }
    }
 
    /// Meals from orders picked up in the last 7 days.
    private var mealsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        let recent = model.orders.filter { $0.status == .pickedUp && $0.createdAt >= weekAgo }
        var meals = 0
        for order in recent {
            for item in order.items {
                meals += item.quantity
            }
        }
        return meals
    }
 
    // MARK: - Screen
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    storeHeader
                    overview
 
                    Button {
                        onAddDeal()
                    } label: {
                        Label("Add a surplus deal", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
 
                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }
 
                    newOrdersSection
                    liveDealsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)   // sign out is in the header instead
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) { auth.signOut() }
            } message: {
                Text("You will need to sign in again to manage your orders.")
            }
            .refreshable { await reload() }   // pull down to refresh
            .task { await reload() }
        }
    }
 
    /// Loads the store, its orders and its deals.
    private func reload() async {
        guard let uid = auth.uid else { return }
        await model.load(ownerId: uid)
        if let storeId = model.store?.id {
            deals = (try? await data.fetchDeals(storeId: storeId)) ?? []
        }
    }
 
    // MARK: - Pieces of the screen
 
    /// Store picture, name and address.
    private var storeHeader: some View {
        HStack(spacing: 12) {
            storeAvatar
            VStack(alignment: .leading, spacing: 2) {
                Text(model.store?.name ?? "Your store")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.ink)
                if let address = model.store?.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }
            }
            Spacer()
 
            // Small square sign out button (icon only)
            Button {
                showSignOutAlert = true   // ask first, do not sign out right away
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
            }
            .accessibilityLabel("Sign out")
        }
    }
 
    /// Store photo if there is one, otherwise a rounded square with a shop icon.
    @ViewBuilder
    private var storeAvatar: some View {
        if let urlString = model.store?.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brandLight
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.brandLight)
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "storefront").foregroundStyle(Color.brand))
        }
    }
 
    /// "Today's overview" with the date and three number boxes.
    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's overview")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
            HStack(spacing: 10) {
                statBox(value: newOrders.count, label: "New orders",
                        textColor: Color(hex: 0xC0392B), background: Color(hex: 0xFDE8E6))
                statBox(value: liveDeals.count, label: "Live deals",
                        textColor: Color.brandDark, background: Color.brandLight)
                statBox(value: mealsThisWeek, label: "Meals saved this week",
                        textColor: Color.brandDark, background: Color.brandLight)
            }
        }
    }
 
    /// One colored box with a big number and a small label.
    private func statBox(value: Int, label: String, textColor: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 26, weight: .heavy))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(textColor)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 14))
    }
 
    // MARK: - New orders
 
    private var newOrdersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("New orders")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Spacer()
                Button("See all") { onSeeOrders() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandText)
            }
 
            if newOrders.isEmpty {
                Text("No new orders right now.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
            }
 
            // Only the 2 newest are shown here. Tapping one opens the order details.
            ForEach(Array(newOrders.prefix(2))) { order in
                NavigationLink {
                    BusinessOrderDetailView(model: model, orderId: order.id ?? "")
                } label: {
                    orderRow(order)
                }
                .buttonStyle(.plain)
            }
        }
    }
 
    /// One order: customer, items, pickup time and status.
    private func orderRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(model.customerName(for: order))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(orderNumber(for: order))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                Spacer()
                StatusBadge(status: order.status)
            }
            Text(order.items.map { "\($0.title) × \($0.quantity)" }.joined(separator: ", "))
                .font(.system(size: 14))
                .foregroundStyle(Color.ink)
                .lineLimit(2)
            HStack(spacing: 8) {
                Label(model.pickupText(for: order), systemImage: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandText)
                // Small yellow tag if the customer wrote a note
                if let notes = order.notes, !notes.isEmpty {
                    Label("Note", systemImage: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Color(hex: 0x9A6B0A))
                        .background(Color(hex: 0xFCEBC8), in: Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
 
    // MARK: - Live deals
 
    private var liveDealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live deals")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Spacer()
                Button("Add new") { onAddDeal() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandText)
            }
 
            if liveDeals.isEmpty {
                Text("No live deals yet. Tap Add new to post one.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
            } else {
                // Only the first 5 deals are shown
                VStack(spacing: 0) {
                    ForEach(Array(liveDeals.prefix(5).enumerated()), id: \.offset) { index, deal in
                        if index > 0 {
                            Divider()
                        }
                        dealRow(deal)
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
 
    /// One deal: name, prices and how many are left.
    private func dealRow(_ deal: Deal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ink)
                HStack(spacing: 6) {
                    Text(qar(deal.dealPrice))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.brandText)
                    Text(qar(deal.originalPrice))
                        .font(.system(size: 11))
                        .strikethrough()
                        .foregroundStyle(Color.muted)
                }
            }
            Spacer()
            Text("\(deal.quantityLeft) left")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(Color.brandDark)
                .background(Color.brandLight, in: Capsule())
        }
        .padding(.vertical, 12)
    }
}
