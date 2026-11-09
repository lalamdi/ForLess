//
//
//
//  FavoritesView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//

import SwiftUI

struct FavoritesView: View {
    @AppStorage("favoriteDealIDs") private var favoriteDealIDs = ""
    @AppStorage("favoriteStoreIDs") private var favoriteStoreIDs = ""

    @StateObject private var data = DataStore()
    @State private var isLoading = true

    private var savedDealIDs: Set<String> {
        Set(favoriteDealIDs.split(separator: ",").map(String.init))
    }

    private var savedStoreIDs: Set<String> {
        Set(favoriteStoreIDs.split(separator: ",").map(String.init))
    }

    private var favoriteDeals: [Deal] {
        data.deals.filter {
            guard let id = $0.id else { return false }
            return savedDealIDs.contains(id) && !$0.isExpired
        }
    }

    private var favoriteStores: [Store] {
        data.stores.filter {
            guard let id = $0.id else { return false }
            return savedStoreIDs.contains(id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Favorites")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color.ink)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else if favoriteDeals.isEmpty && favoriteStores.isEmpty {
                    emptyState
                } else {
                    if !favoriteDeals.isEmpty {
                        sectionTitle("Saved deals")

                        ForEach(favoriteDeals) { deal in
                            NavigationLink {
                                DealDetailView(
                                    deal: deal,
                                    storeName: storeName(for: deal)
                                )
                            } label: {
                                dealRow(deal)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !favoriteStores.isEmpty {
                        sectionTitle("Saved stores")

                        ForEach(favoriteStores) { store in
                            NavigationLink {
                                StoreDealsView(store: store)
                            } label: {
                                storeRow(store)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await data.loadAll()
            isLoading = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 42))
                .foregroundStyle(Color.brand)

            Text("No favorites yet")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.ink)

            Text("Save deals and stores you like, and they will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 65)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(Color.ink)
    }

    private func storeName(for deal: Deal) -> String {
        data.stores.first { $0.id == deal.storeId }?.name ?? "Store"
    }

    private func dealRow(_ deal: Deal) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: deal.photoURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brandLight)
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(deal.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)

                Text(storeName(for: deal))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)

                HStack(spacing: 7) {
                    Text(qar(deal.dealPrice))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.brandDark)

                    Text(qar(deal.originalPrice))
                        .font(.system(size: 12))
                        .strikethrough()
                        .foregroundStyle(Color.muted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.muted)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func storeRow(_ store: Store) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: store.photoURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "storefront")
                    .font(.title2)
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brandLight)
            }
            .frame(width: 65, height: 65)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(store.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)

                Text(store.address)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.muted)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}
