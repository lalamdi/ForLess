//
//  ThankYouView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//
//  Thank-you screen (Figma 11 and 19).
//  Opens from Order tracking when the store marks the order as picked up.
//  Shows what the customer saved, the food rescued, this month's totals,
//  and asks "How was your pickup?". The rating is saved on the order in Firestore.
//

import SwiftUI
import FirebaseFirestore

struct ThankYouView: View {
    let order: Order
    var onBackToHome: () -> Void
    var onViewHistory: () -> Void

    @EnvironmentObject private var auth: AuthManager
    @StateObject private var data = DataStore()

    @State private var rating = 0
    @State private var monthOrders: [Order] = []

    // MARK: - Data for the screen

    private var firstName: String {
        let full = auth.profile?.name ?? ""
        return full.split(separator: " ").first.map(String.init) ?? ""
    }

    /// "Chicken Caesar Wrap" for one item, "order" if there are several.
    private var itemText: String {
        if order.items.count == 1, let item = order.items.first {
            return item.title
        }
        return "order"
    }

    /// True if the first item is a grocery, so we say "item" instead of "meal".
    private var isGrocery: Bool {
        guard let dealId = order.items.first?.dealId else { return false }
        return data.deals.first { $0.id == dealId }?.kind == .grocery
    }

    private var itemCount: Int {
        order.items.reduce(0) { $0 + $1.quantity }
    }

    /// Money saved on one order: (original price - paid price) for each item.
    private func saved(on order: Order) -> Double {
        order.items.reduce(0) { total, item in
            guard let deal = data.deals.first(where: { $0.id == item.dealId }) else {
                return total
            }
            return total + max(0, deal.originalPrice - item.price) * Double(item.quantity)
        }
    }

    /// This month's picked-up orders (includes this one).
    private var monthMeals: Int {
        monthOrders.reduce(0) { total, order in
            total + order.items.reduce(0) { $0 + $1.quantity }
        }
    }

    private var monthSaved: Double {
        monthOrders.reduce(0) { $0 + saved(on: $1) }
    }

    // MARK: - Screen

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    successIcon
                        .padding(.top, 40)

                    // Title and message
                    VStack(spacing: 8) {
                        Text(firstName.isEmpty ? "Thank you!" : "Thank you, \(firstName)!")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(Color.ink)

                        Text("Your order has been picked up. Enjoy your \(itemText)!")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center)
                    }

                    // Saved on this order + rescued from waste
                    HStack(spacing: 12) {
                        statCard(
                            icon: "banknote",
                            value: qar(saved(on: order)),
                            label: "saved on this order"
                        )
                        statCard(
                            icon: "leaf",
                            value: "\(itemCount) \(isGrocery ? (itemCount == 1 ? "item" : "items") : (itemCount == 1 ? "meal" : "meals"))",
                            label: "rescued from waste"
                        )
                    }

                    // This month's totals
                    if !monthOrders.isEmpty {
                        Text("This month: \(monthMeals) \(monthMeals == 1 ? "meal" : "meals") rescued · \(qar(monthSaved)) saved")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
                    }

                    ratingSection
                }
                .padding(.horizontal, 24)
            }

            // Buttons stay at the bottom
            VStack(spacing: 12) {
                Button {
                    onBackToHome()
                } label: {
                    Text("Back to home")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    onViewHistory()
                } label: {
                    Text("View order history")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .task {
            await load()
        }
    }

    // MARK: - Pieces of the screen

    /// Orange circle with a check mark inside a light orange circle.
    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(Color.brandLight)
                .frame(width: 120, height: 120)
            Circle()
                .fill(Color.brand)
                .frame(width: 84, height: 84)
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    /// Light orange box: icon, big number, small text.
    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.brand)
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.brandDark)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.brandDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 16))
    }

    /// "How was your pickup?" with 5 stars. Tapping a star saves the rating.
    private var ratingSection: some View {
        VStack(spacing: 10) {
            Text("How was your pickup?")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ink)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { number in
                    Button {
                        rating = number
                        saveRating(number)
                    } label: {
                        Image(systemName: number <= rating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(number <= rating ? Color.brand : Color.line)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(number) star\(number == 1 ? "" : "s")")
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Loading and saving

    /// Loads the deals (for prices) and this customer's orders this month.
    private func load() async {
        await data.loadAll()

        guard let uid = auth.uid else { return }
        let allOrders = (try? await data.fetchOrders(customerId: uid)) ?? []

        monthOrders = allOrders.filter { item in
            Calendar.current.isDate(item.createdAt, equalTo: Date(), toGranularity: .month)
                && (item.status == .pickedUp || item.id == order.id)
        }
    }

    /// Saves the star rating on the order document.
    private func saveRating(_ stars: Int) {
        guard let orderId = order.id else { return }
        Firestore.firestore()
            .collection("orders")
            .document(orderId)
            .updateData(["rating": stars])
    }
}

// MARK: - Switching tabs from inside a screen

/// Lets a screen deep inside a tab switch the bottom tab (0 Home, 1 Orders, 2 Profile).
/// CustomerTabView sets it; ThankYouView's "Back to home" uses it.
private struct SwitchTabKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    var switchTab: (Int) -> Void {
        get { self[SwitchTabKey.self] }
        set { self[SwitchTabKey.self] = newValue }
    }
}
