//
//  AddDealView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  "Add a surplus deal" screen
//  The business picks Meal or Grocery item, fills in the name, prices,
//  quantity and pickup time, and taps "Publish deal".
//  The deal is saved in the "deals" collection for the business user's store.
//
 

import SwiftUI
 
struct AddDealView: View {
    @EnvironmentObject private var auth: AuthManager   // used for the user's ID
    @StateObject private var data = DataStore()
 
    @State private var store: Store?                   // the store this business user owns
    @State private var kind: DealKind = .meal          // Meal or Grocery item
    @State private var name = ""
    @State private var details = ""                    // short description
    @State private var originalPrice = ""
    @State private var dealPrice = ""
    @State private var quantity = 1
    @State private var pickupStart = AddDealView.today(hour: 17)   // 5:00 PM
    @State private var pickupEnd = AddDealView.today(hour: 19)     // 7:00 PM
    @State private var expiry = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var errorMessage: String?
    @State private var showPublished = false
 
    // MARK: - Example text (changes with Meal / Grocery item)
 
    private var namePlaceholder: String {
        kind == .meal ? "e.g. Chicken Caesar Wrap" : "e.g. Greek Yogurt"
    }
 
    private var detailsPlaceholder: String {
        kind == .meal ? "e.g. Grilled chicken, romaine, parmesan" : "e.g. 4 × 150 g, plain"
    }
 
    private var originalPlaceholder: String {
        kind == .meal ? "32" : "19"
    }
 
    private var dealPlaceholder: String {
        kind == .meal ? "20" : "11"
    }
 
    // MARK: - Prices
 
    /// Original price typed by the business (nil if it is not a number).
    private var original: Double? {
        Double(originalPrice.replacingOccurrences(of: ",", with: "."))
    }
 
    /// Deal price typed by the business (nil if it is not a number).
    private var discounted: Double? {
        Double(dealPrice.replacingOccurrences(of: ",", with: "."))
    }
 
    /// Discount in percent, only when both prices are valid and the deal is cheaper.
    private var discountPercent: Int? {
        guard let originalValue = original, let dealValue = discounted,
              originalValue > 0, dealValue > 0, dealValue < originalValue else { return nil }
        return Int(((originalValue - dealValue) / originalValue * 100).rounded())
    }
 
    // MARK: - Screen
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add a surplus deal")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(Color.ink)
                        Text("Posting for \(store?.name ?? "your store")")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)
                    }
 
                    // Meal or Grocery item
                    Text("What are you selling?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    kindPicker
 
                    LabeledField(label: "Item name") {
                        TextField(namePlaceholder, text: $name)
                    }
 
                    LabeledField(label: "Short description") {
                        TextField(detailsPlaceholder, text: $details)
                    }
 
                    // Prices side by side
                    HStack(spacing: 12) {
                        LabeledField(label: "Original price") {
                            priceField(originalPlaceholder, text: $originalPrice)
                        }
                        LabeledField(label: "Deal price") {
                            priceField(dealPlaceholder, text: $dealPrice)
                        }
                    }
 
                    // Shows the discount once both prices are filled in
                    if let percent = discountPercent {
                        Label("Customers will see \(percent)% off", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.brandDark)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 12))
                    }
 
                    quantityRow
 
                    // Pickup window (today)
                    Text("Pickup window (today)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    HStack(spacing: 12) {
                        LabeledField(label: "From") {
                            DatePicker("", selection: $pickupStart, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        LabeledField(label: "Until") {
                            DatePicker("", selection: $pickupEnd, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
 
                    // Expiry date is only for groceries
                    if kind == .grocery {
                        LabeledField(label: "Expiry date (shown to customers)") {
                            DatePicker("", selection: $expiry, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
 
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)   // drag down to close the keyboard
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            // Publish button stays at the bottom of the screen
            .safeAreaInset(edge: .bottom) {
                Button("Publish deal") { publish() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store == nil)
                    .opacity(store == nil ? 0.5 : 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.appBackground)
            }
            .alert("Deal published", isPresented: $showPublished) {
                Button("OK") {}
            } message: {
                Text("Customers can now see it in the deals list.")
            }
            .task { await loadStore() }
        }
    }
 
    // MARK: - Pieces of the screen
 
    /// Meal / Grocery item switch.
    private var kindPicker: some View {
        HStack(spacing: 4) {
            kindButton("Meal", icon: "fork.knife", value: .meal)
            kindButton("Grocery item", icon: "bag", value: .grocery)
        }
        .padding(4)
        .background(Color(hex: 0xEFE7E1), in: RoundedRectangle(cornerRadius: 14))
    }
 
    private func kindButton(_ title: String, icon: String, value: DealKind) -> some View {
        Button {
            kind = value
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(kind == value ? Color.brandText : Color.muted)
                .background(kind == value ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
 
    /// Price box with "QAR" in front.
    private func priceField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text("QAR").foregroundStyle(Color.brandText)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
        }
    }
 
    /// Quantity with - and + buttons.
    private var quantityRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quantity available")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text("Boxes or portions")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", enabled: quantity > 1) { quantity -= 1 }
                Text("\(quantity)")
                    .font(.system(size: 16, weight: .bold))
                    .frame(minWidth: 20)
                stepButton("plus", enabled: true) { quantity += 1 }
            }
        }
    }
 
    /// The - and + buttons of the quantity.
    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(icon == "plus" ? Color.brand : Color.white, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(icon == "plus" ? Color.white : Color.ink)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(icon == "plus" ? Color.clear : Color.line))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
 
    // MARK: - Loading and saving
 
    /// Finds the store whose ownerId is this user's ID.
    private func loadStore() async {
        guard let uid = auth.uid else { return }
        store = try? await data.fetchStore(ownerId: uid)
        if store == nil {
            errorMessage = "No store is linked to this account yet. In Firestore, set the store's ownerId to your user ID."
        }
    }
 
    /// Checks the form, then saves the deal in Firestore.
    private func publish() {
        errorMessage = nil
 
        guard let storeId = store?.id else {
            errorMessage = "No store is linked to this account yet."
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter the item name."
            return
        }
        guard let originalValue = original, let dealValue = discounted,
              originalValue > 0, dealValue > 0 else {
            errorMessage = "Enter both prices as numbers."
            return
        }
        guard dealValue < originalValue else {
            errorMessage = "The deal price must be lower than the original price."
            return
        }
        let start = todayAt(pickupStart)
        let end = todayAt(pickupEnd)
        guard end > start else {
            errorMessage = "The pickup end time must be after the start time."
            return
        }
 
        // Groceries expire at the end of the chosen day
        let expiryDate: Date? = kind == .grocery
            ? Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: expiry)
            : nil
 
        let newDeal = Deal(
            id: nil,
            storeId: storeId,
            title: trimmedName,
            description: details.trimmingCharacters(in: .whitespacesAndNewlines),
            photoURL: nil,
            kind: kind,
            originalPrice: originalValue,
            dealPrice: dealValue,
            quantityLeft: quantity,
            pickupStart: start,
            pickupEnd: end,
            expiryDate: expiryDate
        )
 
        do {
            _ = try data.createDeal(newDeal)
            showPublished = true
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
 
    /// Empties the form after a deal is published.
    private func clearForm() {
        name = ""
        details = ""
        originalPrice = ""
        dealPrice = ""
        quantity = 1
    }
 
    // MARK: - Dates
 
    /// Today at a given hour, e.g. today(hour: 17) is today at 5:00 PM.
    private static func today(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
 
    /// Takes only the hour and minute from a picked time and puts them on today's date.
    private func todayAt(_ time: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: Date()) ?? time
    }
}

 
