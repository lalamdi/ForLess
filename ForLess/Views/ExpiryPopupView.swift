//
//  ExpiryPopupView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//
import SwiftUI

struct ExpiryPopupView: View {
    let deal: Deal

    @Environment(\.dismiss) private var dismiss

    private var daysRemaining: Int? {
        guard let expiryDate = deal.expiryDate else { return nil }

        let today = Calendar.current.startOfDay(for: Date())
        let expiry = Calendar.current.startOfDay(for: expiryDate)

        return Calendar.current.dateComponents(
            [.day],
            from: today,
            to: expiry
        ).day
    }

    private var expiryMessage: String {
        guard let days = daysRemaining else {
            return "Expiry date unavailable"
        }

        if days < 0 {
            return "This product has expired"
        } else if days == 0 {
            return "Expires today"
        } else if days == 1 {
            return "1 day remaining"
        } else {
            return "\(days) days remaining"
        }
    }

    private var expiryColor: Color {
        guard let days = daysRemaining else {
            return .muted
        }

        return days <= 2 ? .orange : .brand
    }

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.line)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            HStack(spacing: 14) {
                dealImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(deal.title)
                        .font(.headline)
                        .foregroundStyle(Color.ink)

                    Text("Expiry information")
                        .font(.subheadline)
                        .foregroundStyle(Color.muted)
                }

                Spacer()
            }

            Divider()

            VStack(spacing: 12) {
                HStack {
                    Label("Expiry date", systemImage: "calendar")
                        .foregroundStyle(Color.muted)

                    Spacer()

                    Text(
                        deal.expiryDate?.formatted(
                            date: .long,
                            time: .omitted
                        ) ?? "Not available"
                    )
                    .foregroundStyle(Color.ink)
                    .fontWeight(.semibold)
                }

                HStack {
                    Label("Time remaining", systemImage: "clock")
                        .foregroundStyle(Color.muted)

                    Spacer()

                    Text(expiryMessage)
                        .foregroundStyle(expiryColor)
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)

            Text("Please check the expiry date before consuming this product.")
                .font(.footnote)
                .foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color.appBackground)
    }

    private var dealImage: some View {
        AsyncImage(url: URL(string: deal.photoURL ?? "")) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "basket")
                    .font(.title2)
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brandLight)
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
