//
//  BusinessProfileView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Business "Profile" tab: the store's name, address, rating and phone,
//  three totals (total sales, orders done, meals saved), and a menu with
//  Store details (edit) and Sales & analytics. Sign out is at the bottom.
//  The totals only count orders that were picked up.
//

import SwiftUI

struct BusinessProfileView: View {
    @EnvironmentObject private var auth: AuthManager   // used for the user's ID, phone and Sign out
    @StateObject private var model = BusinessOrdersViewModel()
    @State private var showSignOutAlert = false        // confirm pop up for Sign out

    // MARK: - Numbers

    /// Orders the customer already picked up.
    private var doneOrders: [Order] {
        model.orders.filter { $0.status == .pickedUp }
    }

    private var totalSales: Double {
        doneOrders.reduce(0) { $0 + $1.total }
    }

    private var mealsSaved: Int {
        doneOrders.reduce(0) { total, order in
            total + order.items.reduce(0) { $0 + $1.quantity }
        }
    }

    /// "Restaurant · Education City, Doha"
    private var typeAndAddress: String {
        guard let store = model.store else { return "" }
        let type = store.type == .restaurant ? "Restaurant" : "Grocery"
        return store.address.isEmpty ? type : "\(type) · \(store.address)"
    }

    /// "4.6 · +974 4412 7788" (the rating is left out if the store has none)
    private var ratingAndPhone: String {
        var parts: [String] = []
        if let rating = model.store?.rating {
            parts.append("★ " + rating.formatted(.number.precision(.fractionLength(0...1))))
        }
        // The store's contact number, or the sign-in number if none is set
        if let phone = model.store?.phone ?? auth.profile?.phone, !phone.isEmpty {
            parts.append(formatPhone(phone))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Screen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.ink)

                    storeCard
                    statBoxes

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    menuCard
                    signOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await reload() }   // pull down to refresh
            .onAppear { Task { await reload() } }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) { auth.signOut() }
            } message: {
                Text("You will need to sign in again to manage your orders.")
            }
        }
    }

    private func reload() async {
        guard let uid = auth.uid else { return }
        await model.load(ownerId: uid)
    }

    // MARK: - Pieces of the screen

    /// Store picture, name, type, address, rating and phone.
    private var storeCard: some View {
        HStack(spacing: 14) {
            storeAvatar
            VStack(alignment: .leading, spacing: 3) {
                Text(model.store?.name ?? "Your store")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text(typeAndAddress)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                Text(ratingAndPhone)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
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
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandLight)
                .frame(width: 64, height: 64)
                .overlay(Image(systemName: "storefront").foregroundStyle(Color.brand))
        }
    }

    /// Total sales, Orders done and Meals saved.
    private var statBoxes: some View {
        HStack(spacing: 10) {
            statBox(value: qar(totalSales), label: "Total sales",
                    textColor: Color.brandDark, background: Color.brandLight)
            statBox(value: "\(doneOrders.count)", label: "Orders done",
                    textColor: Color(hex: 0x1E6B45), background: Color(hex: 0xE7F3EC))
            statBox(value: "\(mealsSaved)", label: "Meals saved",
                    textColor: Color.brandDark, background: Color.brandLight)
        }
    }

    private func statBox(value: String, label: String, textColor: Color, background: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(background, in: RoundedRectangle(cornerRadius: 14))
    }

    /// White card with the two menu rows.
    private var menuCard: some View {
        VStack(spacing: 0) {
            if let store = model.store {
                NavigationLink {
                    StoreDetailsView(store: store, onSaved: { Task { await reload() } })
                } label: {
                    menuRow(icon: "storefront", title: "Store details", subtitle: "Name and address")
                }
                .buttonStyle(.plain)
            } else {
                menuRow(icon: "storefront", title: "Store details", subtitle: "Name and address")
                    .opacity(0.5)
            }

            Divider()

            NavigationLink {
                SalesAnalyticsView(orders: model.orders, deals: model.deals)
            } label: {
                menuRow(icon: "chart.bar", title: "Sales & analytics", subtitle: "This week, this month, all time")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    /// One menu row: icon, title, small text and an arrow.
    private func menuRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brand)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.muted)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// White Sign out button with red text. It asks to confirm first.
    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0xC0392B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
        }
        .buttonStyle(.plain)
    }
}

/// "+97444127788" becomes "+974 4412 7788".
func formatPhone(_ phone: String) -> String {
    let digits = phone.filter { $0.isNumber }
    if digits.count == 11 && digits.hasPrefix("974") {
        let number = Array(digits.dropFirst(3))
        return "+974 \(String(number[0..<4])) \(String(number[4..<8]))"
    }
    return phone
}
