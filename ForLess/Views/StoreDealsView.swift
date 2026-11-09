//
//  StoreDealsView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//

import SwiftUI

struct StoreDealsView: View {
    let store: Store

    @StateObject private var data = DataStore()
    @State private var storeDeals: [Deal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Store favorite IDs are saved on this device.
    @AppStorage("favoriteStoreIDs") private var favoriteStoreIDs = ""

    private var isFavorite: Bool {
        favoriteStoreIDs
            .split(separator: ",")
            .map(String.init)
            .contains(store.id ?? "")
    }

    private var storeTitle: String {
        store.type == .restaurant ? "Restaurant" : "Grocery store"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                storeHeader
                pickupInformation
                dealsSection
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDeals()
        }
    }

    // MARK: - Store information

    private var storeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Store picture
            Group {
                if let photoURL = store.photoURL,
                   let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        storeImagePlaceholder
                    }
                } else {
                    storeImagePlaceholder
                }
            }
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.name)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text(storeTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.muted)

                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.brand)

                        Text(store.rating.map {
                            String(format: "%.1f", $0)
                        } ?? "No rating yet")
                        .foregroundStyle(Color.ink)
                        .font(.system(size: 13, weight: .semibold))
                    }
                }

                Spacer()

                // Favorite store button
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(isFavorite ? Color.brand : Color.muted)
                        .padding(12)
                        .background(Color.brandLight, in: Circle())
                }
                .accessibilityLabel(
                    isFavorite ? "Remove store from favorites" : "Add store to favorites"
                )
            }

            Label(store.address, systemImage: "mappin.and.ellipse")
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
        }
    }

    private var storeImagePlaceholder: some View {
        ZStack {
            Color.brandLight

            Image(systemName: store.type == .restaurant
                  ? "fork.knife"
                  : "basket")
                .font(.system(size: 42))
                .foregroundStyle(Color.brand)
        }
    }

    // MARK: - Pickup information

    private var pickupInformation: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 20))
                .foregroundStyle(Color.brand)

            VStack(alignment: .leading, spacing: 3) {
                Text("Pickup information")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ink)

                Text("Pickup times are listed on each deal.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Deals

    private var dealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available deals")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.ink)

            if isLoading {
                ProgressView("Loading deals...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            } else if storeDeals.isEmpty {
                Text("There are no available deals at this store right now.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .padding()
            } else {
                ForEach(storeDeals) { deal in
                    NavigationLink {
                        DealDetailView(deal: deal, storeName: store.name)
                    } label: {
                        dealCard(deal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dealCard(_ deal: Deal) -> some View {
        HStack(spacing: 12) {
            Group {
                if let photoURL = deal.photoURL,
                   let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        dealImagePlaceholder(deal)
                    }
                } else {
                    dealImagePlaceholder(deal)
                }
            }
            .frame(width: 105, height: 105)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(deal.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)

                Text("\(deal.quantityLeft) left")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)

                HStack(spacing: 7) {
                    Text("QAR \(deal.dealPrice, specifier: "%.2f")")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandText)

                    Text("QAR \(deal.originalPrice, specifier: "%.2f")")
                        .font(.system(size: 11))
                        .strikethrough()
                        .foregroundStyle(Color.muted)
                }

                Text("\(deal.discountPercent)% OFF")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandText)

                Text(
                    "\(deal.pickupStart.formatted(date: .omitted, time: .shortened)) – \(deal.pickupEnd.formatted(date: .omitted, time: .shortened))"
                )
                .font(.system(size: 11))
                .foregroundStyle(Color.muted)

                if let expiryDate = deal.expiryDate {
                    Text("Expires \(expiryDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brandText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dealImagePlaceholder(_ deal: Deal) -> some View {
        ZStack {
            Color.brandLight

            Image(systemName: deal.kind == .grocery ? "basket" : "fork.knife")
                .font(.system(size: 26))
                .foregroundStyle(Color.brand)
        }
    }

    // MARK: - Load and filter deals

    private func loadDeals() async {
        guard let storeID = store.id else {
            errorMessage = "This store does not have an ID."
            isLoading = false
            return
        }

        do {
            let allStoreDeals = try await data.fetchDeals(storeId: storeID)

            // Only show deals from this store that are still available.
            storeDeals = allStoreDeals.filter { $0.quantityLeft > 0 && !$0.isExpired }
                .sorted { $0.dealPrice < $1.dealPrice }

            errorMessage = nil
        } catch {
            errorMessage = "Could not load deals: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Favorite button

    private func toggleFavorite() {
        guard let storeID = store.id else { return }

        var favorites = Set(
            favoriteStoreIDs.split(separator: ",").map(String.init)
        )

        if favorites.contains(storeID) {
            favorites.remove(storeID)
        } else {
            favorites.insert(storeID)
        }

        favoriteStoreIDs = favorites.sorted().joined(separator: ",")
    }
}
