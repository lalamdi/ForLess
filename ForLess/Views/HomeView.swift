//
//  HomeView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Customer home screen
//  Top: "Pickup near" chip (opens the location pop-up) and the profile circle.
//  Then the greeting, a search box, the Restaurants / Groceries switch,
//  "Buy again" from past orders, and the deals list.
//  Tapping a store opens its deals page; tapping a deal opens Deal details.
//
 
import SwiftUI
 
struct HomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var data = DataStore()
 
    @State private var orders: [Order] = []            // this customer's past orders
    @State private var searchText = ""
    @State private var mode: StoreType = .restaurant   // Restaurants or Groceries
 
    @Binding var chosenPlace: LocationOption?        // place confirmed in the pop-up
    @State private var showLocationSheet = false
    @State private var didAskLocation = false          // pop-up opens by itself only once
    @State private var showAddAddress = false          // Add address screen (opens on top of the pop-up)
    @State private var showSignOutAlert = false
 
    // MARK: - Data for the screen
 
    /// First word of the customer's name, for "Hi Leen".
    private var firstName: String {
        let full = auth.profile?.name ?? ""
        return full.split(separator: " ").first.map(String.init) ?? ""
    }
 
    /// The customer's saved addresses, in the form the pop-up needs.
    private var savedPlaces: [LocationOption] {
        let saved = auth.profile?.savedLocations ?? []
        return saved.map { place in
            LocationOption(
                id: place.label + place.address,
                title: place.label,
                address: place.address,
                icon: iconName(for: place.label)
            )
        }
    }
 
    /// Deals of the selected type (restaurants or groceries) that are not sold out.
    private var modeDeals: [Deal] {
        let storeIds = Set(data.stores.filter { $0.type == mode }.compactMap { $0.id })
        return data.deals.filter { storeIds.contains($0.storeId) && $0.quantityLeft > 0 }
    }
 
    /// The deals list after the search box is applied.
    private var searchedDeals: [Deal] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return modeDeals }
        return modeDeals.filter { deal in
            deal.title.localizedCaseInsensitiveContains(text)
                || storeName(for: deal).localizedCaseInsensitiveContains(text)
        }
    }
 
    /// Up to 2 deals the customer ordered before and that are still available.
    private var buyAgainDeals: [Deal] {
        var result: [Deal] = []
        for order in orders {
            for item in order.items {
                if let deal = modeDeals.first(where: { $0.id == item.dealId }),
                   !result.contains(where: { $0.id == deal.id }) {
                    result.append(deal)
                }
            }
        }
        return Array(result.prefix(2))
    }
 
    /// Stores of the selected type that have at least one deal left.
    private var modeStores: [Store] {
        let storeIdsWithDeals = Set(modeDeals.map { $0.storeId })
        return data.stores.filter { store in
            guard let id = store.id else { return false }
            return store.type == mode && storeIdsWithDeals.contains(id)
        }
    }

    private func storeName(for deal: Deal) -> String {
        data.stores.first { $0.id == deal.storeId }?.name ?? ""
    }
 
    // MARK: - Screen
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    greeting
                    searchBox
                    modeSwitch
 
                    if let error = data.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }
 
                    // Buy again is hidden while searching
                    if searchText.isEmpty && !buyAgainDeals.isEmpty {
                        buyAgainSection
                    }

                    // Stores near you (opens the store deals page, Figma 07 / 14)
                    if searchText.isEmpty && !modeStores.isEmpty {
                        storesSection
                    }
 
                    dealsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                // Open the location pop-up the first time only
                if !didAskLocation {
                    didAskLocation = true
                    showLocationSheet = true
                }
                await reload()
            }
            .refreshable { await reload() }
            .sheet(isPresented: $showLocationSheet) {
                LocationPopupView(
                    savedPlaces: savedPlaces,
                    onConfirm: { place in
                        chosenPlace = place
                        showLocationSheet = false
                    },
                    onAddAddress: {
                        showAddAddress = true
                    }
                )
                // Opens from the pop-up, so it shows on top of it
                .sheet(isPresented: $showAddAddress) {
                    AddAddressView()
                }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackground)
            }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) { auth.signOut() }
            } message: {
                Text("You will need to sign in again to order.")
            }
        }
    }
 
    /// Loads the stores, the deals and this customer's orders.
    private func reload() async {
        await data.loadAll()
        if let uid = auth.uid {
            orders = (try? await data.fetchOrders(customerId: uid)) ?? []
        }
    }
 
    // MARK: - Pieces of the screen
 
    /// "Pickup near" chip on the left, profile circle on the right.
    private var header: some View {
        HStack(alignment: .top) {
            Button {
                showLocationSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pickup near")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brand)
                        Text(chosenPlace?.address ?? "Choose location")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.ink)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.muted)
                    }
                }
            }
            .buttonStyle(.plain)
 
            Spacer()
 
            // Orange circle with the first letter of the name. Tap to sign out.
            Button {
                showSignOutAlert = true
            } label: {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(firstName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                    )
            }
            .accessibilityLabel("Account")
        }
    }
 
    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(firstName.isEmpty ? "Hi there" : "Hi \(firstName)")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color.ink)
            Text(mode == .restaurant ? "Rescue a great meal for less today."
                                     : "Fresh groceries for less, near you.")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)
        }
    }
 
    /// White search box. It filters the deals by item or store name.
    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.muted)
            TextField(mode == .restaurant ? "Search restaurants or dishes" : "Search groceries or stores",
                      text: $searchText)
                .font(.system(size: 15))
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.muted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
    }
 
    /// Restaurants / Groceries switch.
    private var modeSwitch: some View {
        HStack(spacing: 4) {
            modeButton("Restaurants", icon: "fork.knife", value: .restaurant)
            modeButton("Groceries", icon: "bag", value: .grocery)
        }
        .padding(4)
        .background(Color(hex: 0xEFE7E1), in: RoundedRectangle(cornerRadius: 14))
    }
 
    private func modeButton(_ title: String, icon: String, value: StoreType) -> some View {
        Button {
            mode = value
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(mode == value ? Color.ink : Color.muted)
                .background(mode == value ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
 
    // MARK: - Buy again
 
    private var buyAgainSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Buy again")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text("From your past orders")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach(buyAgainDeals) { deal in
                    NavigationLink {
                        DealDetailView(
                            deal: deal,
                            storeName: storeName(for: deal)
                        )
                    } label: {
                        buyAgainCard(deal)
                    }
                    .buttonStyle(.plain)
                }
                // Keeps a single card at half width
                if buyAgainDeals.count == 1 {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }
 
    private func buyAgainCard(_ deal: Deal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            dealImage(deal)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(deal.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
            Text(storeName(for: deal))
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
                .lineLimit(1)
            priceLine(deal)
            Label("Buy again", systemImage: "arrow.2.squarepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
 
    // MARK: - Stores near you

    private var storesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode == .restaurant ? "Restaurants near you" : "Stores near you")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Color.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(modeStores) { store in
                        NavigationLink {
                            StoreDealsView(store: store)
                        } label: {
                            storeCard(store)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func storeCard(_ store: Store) -> some View {
        let dealCount = modeDeals.filter { $0.storeId == store.id }.count

        return VStack(alignment: .leading, spacing: 6) {
            Group {
                if let urlString = store.photoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.brandLight
                    }
                } else {
                    Color.brandLight
                        .overlay(
                            Image(systemName: store.type == .grocery ? "basket" : "fork.knife")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.brand)
                        )
                }
            }
            .frame(width: 150, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(store.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)

            Text("\(dealCount) \(dealCount == 1 ? "deal" : "deals") left")
                .font(.system(size: 12))
                .foregroundStyle(Color.brandText)
        }
        .frame(width: 150, alignment: .leading)
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Deals list
 
    private var dealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(searchText.isEmpty ? "Deals near you" : "Results")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text(mode == .restaurant ? "Surplus meals ready for pickup today"
                                         : "Groceries close to their best-before date")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
            }
 
            if searchedDeals.isEmpty {
                Text(searchText.isEmpty ? "No deals yet." : "No deals match your search.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .padding(.top, 4)
            }
 
            ForEach(searchedDeals) { deal in
                if let store = data.stores.first(where: { $0.id == deal.storeId }) {
                    NavigationLink {
                        DealDetailView(
                            deal: deal,
                            storeName: store.name
                        )
                    } label: {
                        dealRow(deal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
 
    private func dealRow(_ deal: Deal) -> some View {
        HStack(spacing: 12) {
            dealImage(deal)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(deal.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text("\(storeName(for: deal)) · \(deal.quantityLeft) left")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    priceLine(deal)
                    Text("-\(deal.discountPercent)%")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Color(hex: 0xC0392B))
                        .background(Color(hex: 0xFDE8E6), in: Capsule())
                }
                // Only grocery items have an expiry date
                if let expiry = deal.expiryDate {
                    Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brandText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
 
    // MARK: - Small helpers
 
    /// Deal price in orange with the original price crossed out.
    private func priceLine(_ deal: Deal) -> some View {
        HStack(spacing: 6) {
            Text(qar(deal.dealPrice))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.brandText)
            Text(qar(deal.originalPrice))
                .font(.system(size: 11))
                .strikethrough()
                .foregroundStyle(Color.muted)
        }
    }
 
    /// The deal's photo, or a light orange box with an icon if it has none.
    @ViewBuilder
    private func dealImage(_ deal: Deal) -> some View {
        if let urlString = deal.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brandLight
            }
        } else {
            Color.brandLight
                .overlay(
                    Image(systemName: deal.kind == .grocery ? "bag" : "fork.knife")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brand)
                )
        }
    }
 
    /// Icon for a saved address label.
    private func iconName(for label: String) -> String {
        switch label {
        case "Home": return "house"
        case "Work": return "briefcase"
        default: return "mappin"
        }
    }
}
