//
//  ProfileView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//

//  Customer "Profile" screen : the customer's name and phone,
//  three number boxes (orders, saved, meals rescued) and a menu.
//  Order history, Payment methods, Notifications and Help & support open
//  their own screens. Log out asks to confirm first.
//
 

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var data = DataStore()

    @State private var orders: [Order] = []
    @State private var showLogoutAlert = false

    var onSeeOrders: () -> Void

    // MARK: - Data for the screen

    private var profile: User? {
        auth.profile
    }

    /// Cancelled orders are not counted.
    private var countedOrders: [Order] {
        orders.filter { $0.status != .cancelled }
    }

    /// Money saved: (original price - deal price) for every item ordered.
    private var totalSaved: Double {
        var total = 0.0

        for order in countedOrders {
            for item in order.items {
                if let deal = data.deals.first(where: { $0.id == item.dealId }) {
                    total += max(0, deal.originalPrice - item.price) * Double(item.quantity)
                }
            }
        }

        return total
    }

    /// Deals the customer actually picked up.
    private var mealsRescued: Int {
        orders.filter { $0.status == .pickedUp }
            .reduce(0) { total, order in
                total + order.items.reduce(0) { $0 + $1.quantity }
            }
    }

    /// Formats the Qatar phone number.
    private var phoneText: String {
        let phone = profile?.phone ?? ""
        let digits = phone.filter { $0.isNumber }

        if digits.count == 11 && digits.hasPrefix("974") {
            let number = Array(digits.dropFirst(3))
            return "+974 \(String(number[0..<4])) \(String(number[4..<8]))"
        }

        return phone
    }

    private var savedLocationsText: String {
        let labels = (profile?.savedLocations ?? []).map { $0.label }
        return labels.isEmpty ? "None yet" : labels.joined(separator: ", ")
    }

    // MARK: - Screen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.ink)

                    userCard
                    statBoxes
                    menuCard
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                Task {
                    await reload()
                }
            }
            .refreshable {
                await reload()
            }
            .alert("Log out?", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}

                Button("Log out", role: .destructive) {
                    auth.signOut()
                }
            } message: {
                Text("You will need to sign in again to order.")
            }
        }
    }

    /// Loads the deals (for the savings) and this customer's orders.
    private func reload() async {
        await data.loadAll()

        if let uid = auth.uid {
            orders = (try? await data.fetchOrders(customerId: uid)) ?? []
        }
    }

    // MARK: - User card

    private var userCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.brand)
                .frame(width: 64, height: 64)
                .overlay {
                    Text(String((profile?.name ?? "").prefix(1)).uppercased())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.name ?? "")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.ink)

                Text(phoneText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Statistics

    private var statBoxes: some View {
        HStack(spacing: 10) {
            statBox(value: "\(countedOrders.count)", label: "Orders")
            statBox(value: qar(totalSaved), label: "Saved")
            statBox(value: "\(mealsRescued)", label: "Meals rescued")
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.brandDark)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.brandDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Menu

    private var menuCard: some View {
        VStack(spacing: 0) {

            // Order history
            Button {
                onSeeOrders()
            } label: {
                rowContent(
                    icon: "doc.text",
                    title: "Order history",
                    subtitle: "\(countedOrders.count) past orders",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider()

            // Favorites
            NavigationLink {
                FavoritesView()
            } label: {
                rowContent(
                    icon: "heart",
                    title: "Favorites",
                    subtitle: "Your saved deals and stores",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider()

            // Saved locations
            NavigationLink {
                SavedLocationsView()
            } label: {
                rowContent(
                    icon: "mappin.and.ellipse",
                    title: "Saved locations",
                    subtitle: savedLocationsText,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider()

            // Payment methods
            NavigationLink {
                PaymentMethodsView()
            } label: {
                rowContent(
                    icon: "creditcard",
                    title: "Payment methods",
                    subtitle: "Apple Pay, Pay at pickup",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider()

            // Notifications
            NavigationLink {
                NotificationsView()
            } label: {
                rowContent(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: "Deals near you",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider()

            // Help and support
            NavigationLink {
                HelpSupportView()
            } label: {
                rowContent(
                    icon: "questionmark.circle",
                    title: "Help & support",
                    subtitle: nil,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    /// One menu row: icon, title, subtitle and arrow.
    private func rowContent(
        icon: String,
        title: String,
        subtitle: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brand)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0xC0392B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.line)
                }
        }
        .buttonStyle(.plain)
    }
}
