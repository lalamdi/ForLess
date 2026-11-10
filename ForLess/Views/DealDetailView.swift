//
//  DealDetailView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//

import SwiftUI
import FirebaseFirestore

struct DealDetailView: View {
    let deal: Deal
    let storeName: String
    var fromStore = false          // true when opened from the store's own page

    @EnvironmentObject private var cart: CartStore
    @Environment(\.dismiss) private var dismiss

    @State private var quantity = 1
    @State private var showNewCartAlert = false
    @State private var openedStore: Store?          // the store page opened after adding
    @State private var showStore = false
    @State private var showingExpiryDetails = false

    // Save favorite deal IDs on this device.
    @AppStorage("favoriteDealIDs") private var favoriteDealIDs = ""

    private var isFavorite: Bool {
        favoriteDealIDs
            .split(separator: ",")
            .map(String.init)
            .contains(deal.id ?? "")
    }

    private var isGrocery: Bool {
        deal.kind == .grocery
    }

    private var totalPrice: Double {
        deal.dealPrice * Double(quantity)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dealImage

                // Deal title and favorite button
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(deal.title)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Color.ink)

                        Text(storeName)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.muted)
                    }

                    Spacer()

                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 21))
                            .foregroundStyle(
                                isFavorite ? Color.brand : Color.muted
                            )
                            .padding(12)
                            .background(Color.brandLight, in: Circle())
                    }
                    .accessibilityLabel(
                        isFavorite
                        ? "Remove from favorites"
                        : "Add to favorites"
                    )
                }

                // Discount and prices
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(qar(deal.dealPrice))
                            .font(.system(size: 25, weight: .heavy))
                            .foregroundStyle(Color.brandText)

                        Text(qar(deal.originalPrice))
                            .font(.system(size: 16))
                            .strikethrough()
                            .foregroundStyle(Color.muted)

                        Spacer()

                        Text("\(deal.discountPercent)% OFF")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.brandDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.brandLight, in: Capsule())
                    }

                    Text(
                        "You save \(qar(deal.originalPrice - deal.dealPrice)) per item."
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(Color.brandText)
                }

                Divider()

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About this deal")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text(deal.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Pickup details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pickup information")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.ink)

                    detailRow(
                        icon: "clock",
                        title: "Pickup time",
                        value: "\(deal.pickupStart.formatted(date: .omitted, time: .shortened)) – \(deal.pickupEnd.formatted(date: .omitted, time: .shortened))"
                    )

                    detailRow(
                        icon: "storefront",
                        title: "Store",
                        value: storeName
                    )

                    detailRow(
                        icon: "cube.box",
                        title: "Availability",
                        value: "\(deal.quantityLeft) available"
                    )
                }
                .padding(16)
                .background(
                    Color.white,
                    in: RoundedRectangle(cornerRadius: 16)
                )

                // Expiry information for grocery deals
                if isGrocery, let expiryDate = deal.expiryDate {
                    Button {
                        showingExpiryDetails = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundStyle(Color.brand)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expiry date")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.ink)

                                Text(
                                    expiryDate.formatted(
                                        date: .long,
                                        time: .omitted
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(Color.muted)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.muted)
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.brandLight,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Quantity selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quantity")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.ink)

                    HStack {
                        Text("Choose how many you want")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)

                        Spacer()

                        Button {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 35, height: 35)
                                .background(Color.brandLight, in: Circle())
                                .foregroundStyle(Color.brand)
                        }
                        .disabled(quantity <= 1)

                        Text("\(quantity)")
                            .font(.system(size: 16, weight: .bold))
                            .frame(minWidth: 25)

                        Button {
                            if quantity < deal.quantityLeft {
                                quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 35, height: 35)
                                .background(Color.brand, in: Circle())
                                .foregroundStyle(.white)
                        }
                        .disabled(quantity >= deal.quantityLeft)
                    }
                }
                .padding(16)
                .background(
                    Color.white,
                    in: RoundedRectangle(cornerRadius: 16)
                )

                // Total
                HStack {
                    Text("Total")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Spacer()

                    Text(qar(totalPrice))
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color.brandText)
                }
                .padding(.vertical, 5)
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("Deal details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                addToCart()
            } label: {
                Text("Add to cart · \(qar(totalPrice))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(deal.quantityLeft < 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.appBackground)
        }
        // Expiry information bottom sheet
        .sheet(isPresented: $showingExpiryDetails) {
            ExpiryPopupView(deal: deal)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // A cart can only hold items from one store
        .alert("Start a new cart?", isPresented: $showNewCartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Start new cart", role: .destructive) {
                cart.clear()
                cart.add(deal, storeName: storeName, quantity: quantity)
                goToStore()
            }
        } message: {
            Text("Your cart has items from \(cart.storeName). You can only order from one store at a time.")
        }
        // The store page of this deal (when it was not opened from there)
        .navigationDestination(isPresented: $showStore) {
            if let openedStore {
                StoreDealsView(store: openedStore)
            }
        }
    }

    // MARK: - Cart

    /// Puts the deal in the cart and goes to the store.
    private func addToCart() {
        if cart.isOtherStore(deal) {
            showNewCartAlert = true
        } else {
            cart.add(deal, storeName: storeName, quantity: quantity)
            goToStore()
        }
    }

    /// Back to the store page. From Home or Favorites it opens the store of this deal.
    private func goToStore() {
        if fromStore {
            dismiss()
            return
        }
        Task {
            let snapshot = try? await Firestore.firestore()
                .collection("stores")
                .document(deal.storeId)
                .getDocument()
            if var store = try? snapshot?.data(as: Store.self) {
                store.id = deal.storeId
                openedStore = store
                showStore = true
            } else {
                dismiss()   // could not load the store, so just go back
            }
        }
    }

    // MARK: - Deal image

    private var dealImage: some View {
        Group {
            if let photoURL = deal.photoURL,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        imagePlaceholder
                    } else {
                        ZStack {
                            Color.brandLight
                            ProgressView()
                        }
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(height: 230)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.brandLight

            Image(systemName: isGrocery ? "basket" : "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(Color.brand)
        }
    }

    // MARK: - Information row

    private func detailRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.brand)
                .frame(width: 25)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }

            Spacer()
        }
    }

    // MARK: - Favorites

    private func toggleFavorite() {
        guard let dealID = deal.id else { return }

        var favorites = Set(
            favoriteDealIDs.split(separator: ",").map(String.init)
        )

        if favorites.contains(dealID) {
            favorites.remove(dealID)
        } else {
            favorites.insert(dealID)
        }

        favoriteDealIDs = favorites.sorted().joined(separator: ",")
    }
}
