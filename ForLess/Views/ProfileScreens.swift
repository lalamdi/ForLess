//
//  ProfileScreens.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  The screens opened from the Profile menu:
//  Payment methods, Notifications and Help & support.
//  They are simple screens: payments are not connected to a real provider,
//  the notification switches are only saved on this phone,
//  and Help & support copies the team email.
//
 
import SwiftUI
 
// MARK: - Payment methods
 
struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved methods")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.muted)
 
            methodRow(icon: "iphone", title: "Apple Pay", subtitle: "Fast and secure", isDefault: true)
            methodRow(icon: "creditcard", title: "Visa \u{2022}\u{2022}\u{2022}\u{2022} 4821", subtitle: "Expires 08/28", isDefault: false)
            methodRow(icon: "banknote", title: "Pay at pickup", subtitle: "Cash or card at the store", isDefault: false)
 
            // Note box
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(Color.brand)
                Text("Card details are kept by Apple Pay and the payment provider. For Less never stores your full card number.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.brandDark)
            }
            .padding(14)
            .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 14))
 
            Spacer()
 
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Color.appBackground)
        .navigationTitle("Payment methods")
        .navigationBarTitleDisplayMode(.inline)
    }
 
    private func methodRow(icon: String, title: String, subtitle: String, isDefault: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(isDefault ? Color.brandLight : Color.appBackground)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).foregroundStyle(isDefault ? Color.brand : Color.ink))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
            Spacer()
            if isDefault {
                Text("Default")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(Color.brandDark)
                    .background(Color.brandLight, in: Capsule())
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
}
 
// MARK: - Notifications
 
struct NotificationsView: View {
    // The switches are remembered on this phone
    @AppStorage("notifyNewDeals") private var newDeals = true
    @AppStorage("notifyOrderUpdates") private var orderUpdates = true
    @AppStorage("notifyFavorites") private var favorites = true
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    toggleRow("New deals near you", "When stores near your location post surplus food", $newDeals)
                    Divider()
                    toggleRow("Order updates", "When your order is confirmed, ready and picked up", $orderUpdates)
                    Divider()
                    toggleRow("Favorite stores", "Deals from stores you saved with the heart", $favorites)
                }
                .padding(.horizontal, 14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
 
                Text("You can change these anytime. Pickup reminders are always sent for active orders.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
 
    private func toggleRow(_ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
        }
        .tint(Color.brand)
        .padding(.vertical, 12)
    }
}
 
// MARK: - Help & support
 
struct HelpSupportView: View {
    // Change this to the team's support email
    private let supportEmail = "support@forless.app"
    @State private var copied = false
 
    private let questions: [(String, String)] = [
        ("How does pickup work?", "Pay in the app, then go to the store during the pickup time and show your 4-digit pickup code."),
        ("Can I cancel an order?", "You can cancel until the store starts preparing it. After that, the food is kept for you."),
        ("What if the store runs out?", "If a store can't complete your order, it is cancelled and you are refunded in full."),
        ("Why do grocery items show an expiry date?", "So you know how long the item stays fresh after pickup.")
    ]
 
    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(questions, id: \.0) { question in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.0)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.ink)
                            Text(question.1)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    }

                    // The team email
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Still need help?")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.brandDark)
                        Text(supportEmail)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            // Copies the email
            Button {
                UIPasteboard.general.string = supportEmail
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Label(copied ? "Email copied" : "Copy email",
                      systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Color.appBackground)
        .navigationTitle("Help & support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
