//
//  ContentView.swift
//  ForLess
//
//
//  Temporary home screen: lists deals from Firestore grouped by store.
//  Tapping a deal opens Checkout. Hadeel's "Nearby Restaurants" button
//  opens the Google Places screen.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var data = DataStore()
    @EnvironmentObject private var auth: AuthManager   // used for Sign out

    var body: some View {
        NavigationStack {
            List {
                if let error = data.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if data.deals.isEmpty {
                    Section {
                        Text("No deals yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                // One section per store with its deals
                ForEach(data.stores) { store in
                    let storeDeals = data.deals.filter {
                        $0.storeId == store.id
                    }

                    if !storeDeals.isEmpty {
                        Section(store.name) {
                            ForEach(storeDeals) { deal in
                                // Tapping a deal opens Checkout
                                NavigationLink {
                                    CheckoutView(deal: deal, storeName: store.name)
                                } label: {
                                    DealRow(deal: deal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("For Less deals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign out") { auth.signOut() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Nearby Restaurants") {
                        GooglePlacesTestView()
                    }
                }
            }
            .task {
                await data.loadAll()
            }
            .refreshable {
                await data.loadAll()
            }
        }
    }
}

/// One deal in the list: name, discount, prices, quantity left and expiry.
struct DealRow: View {
    let deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(deal.title)
                    .font(.headline)

                Spacer()

                Text("-\(deal.discountPercent)%")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            HStack(spacing: 6) {
                Text("QAR \(deal.dealPrice, specifier: "%.0f")")
                    .bold()
                    .foregroundStyle(Color.brandText)

                // Original price, crossed out
                Text("QAR \(deal.originalPrice, specifier: "%.0f")")
                    .strikethrough()
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(deal.quantityLeft) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Only grocery items have an expiry date
            if let expiry = deal.expiryDate {
                Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.brandText)
            }
        }
        .padding(.vertical, 2)
    }
}
