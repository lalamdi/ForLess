//
//  ContentView.swift
//  ForLess
//
//
import SwiftUI

struct ContentView: View {
    @StateObject private var data = DataStore()

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

                ForEach(data.stores) { store in
                    let storeDeals = data.deals.filter {
                        $0.storeId == store.id
                    }

                    if !storeDeals.isEmpty {
                        Section(store.name) {
                            ForEach(storeDeals) { deal in
                                DealRow(deal: deal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("For Less deals")
            .toolbar {
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
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 6) {
                Text("QAR \(deal.dealPrice, specifier: "%.0f")")
                    .bold()
                    .foregroundStyle(.green)

                Text("QAR \(deal.originalPrice, specifier: "%.0f")")
                    .strikethrough()
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(deal.quantityLeft) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let expiry = deal.expiryDate {
                Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
