//
//  BusinessOrderDetailView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Business side order screen:
//  - New: Decline, or "Accept & start preparing"
//  - Preparing: "Mark as ready for pickup"
//  - Ready: type the customer's 4-digit pickup code, then "Confirm pickup"
//  - After pickup: the "Order picked up" screen
//  The code is checked against the pickupCode saved when the customer paid.
//
 
import SwiftUI
 
struct BusinessOrderDetailView: View {
    @ObservedObject var model: BusinessOrdersViewModel   // same one as the list, so both stay updated
    let orderId: String
 
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""                 // the code typed by the business
    @FocusState private var codeFocused: Bool
    @State private var isWorking = false         // true while a status is being saved
    @State private var showDecline = false
    @State private var showCompleted = false
 
    /// The latest version of this order (changes when the status changes).
    private var currentOrder: Order? {
        model.orders.first { $0.id == orderId }
    }
 
    var body: some View {
        Group {
            if let order = currentOrder {
                content(order)
            } else {
                ProgressView()
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(currentOrder.map { "Order \(orderNumber(for: $0))" } ?? "Order")
    }
 
    // MARK: - Screen
 
    private func content(_ order: Order) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(placedText(order))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                    Spacer()
                    StatusBadge(status: order.status)
                }
 
                if order.status == .cancelled {
                    banner("This order was declined.", color: Color.muted, background: Color.line)
                } else {
                    timeline(order)
                }
 
                if order.status == .preparing {
                    banner("\(model.customerName(for: order)) was told the order is being prepared.",
                           color: Color(hex: 0x2F5D9E), background: Color(hex: 0xE3EEFB))
                }
 
                customerCard(order)
 
                // The code box only shows once the order is ready
                if order.status == .ready {
                    codeCard(order)
                }
 
                itemsCard(order)
 
                if let notes = order.notes, !notes.isEmpty {
                    notesCard(notes)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) { actionBar(order) }
        .alert("Decline this order?", isPresented: $showDecline) {
            Button("Decline order", role: .destructive) {
                Task {
                    if await model.setStatus(order, to: .cancelled) { dismiss() }
                }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The order will be marked as cancelled.")
        }
        // After "Confirm pickup", show the finished screen. When it closes, go back to the list.
        .fullScreenCover(isPresented: $showCompleted, onDismiss: { dismiss() }) {
            BusinessOrderCompletedView(model: model, orderId: orderId)
        }
    }
 
    /// "Placed 4:50 PM · Paid with Apple Pay"
    private func placedText(_ order: Order) -> String {
        let time = order.createdAt.formatted(date: .omitted, time: .shortened)
        let payment = order.paymentMethod == .payAtPickup
            ? "Pay at pickup"
            : "Paid with \(order.paymentMethod.title)"
        return "Placed \(time) · \(payment)"
    }
 
    // MARK: - Steps at the top (New, Preparing, Ready, Picked up)
 
    private func timeline(_ order: Order) -> some View {
        let steps: [(status: OrderStatus, title: String)] = [
            (.new, "New"), (.preparing, "Preparing"), (.ready, "Ready"), (.pickedUp, "Picked up")
        ]
        let current = steps.firstIndex { $0.status == order.status } ?? 0
        let finished = order.status == .pickedUp
 
        return HStack(alignment: .top, spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                // Line between two steps, orange once that step is reached
                if index > 0 {
                    Rectangle()
                        .fill(index <= current ? Color.brand : Color.line)
                        .frame(height: 2)
                        .padding(.top, 10)
                }
                VStack(spacing: 6) {
                    stepDot(done: index < current || finished, active: index == current && !finished)
                    Text(steps[index].title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(index <= current ? Color.ink : Color.muted)
                }
                .frame(width: 64)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
 
    /// One circle of the steps: done = check mark, active = orange ring, otherwise grey.
    @ViewBuilder
    private func stepDot(done: Bool, active: Bool) -> some View {
        if done {
            Circle()
                .fill(Color.brand)
                .frame(width: 22, height: 22)
                .overlay(Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white))
        } else if active {
            Circle()
                .stroke(Color.brand, lineWidth: 2)
                .frame(width: 22, height: 22)
                .overlay(Circle().fill(Color.brand).frame(width: 10, height: 10))
        } else {
            Circle()
                .stroke(Color.line, lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }
 
    /// Colored message box.
    private func banner(_ text: String, color: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
    }
 
    // MARK: - Customer, items and notes
 
    /// Customer name, pickup time and a call button.
    private func customerCard(_ order: Order) -> some View {
        let name = model.customerName(for: order)
        return HStack(spacing: 12) {
            // Circle with the first letter of the name
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.brand, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(model.pickupText(for: order))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandText)
            }
            Spacer()
            // Call button opens the phone app with the customer's number
            if let phone = model.customerPhone(for: order),
               let url = URL(string: "tel:" + phone.replacingOccurrences(of: " ", with: "")) {
                Link(destination: url) {
                    Image(systemName: "phone")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brandText)
                        .frame(width: 40, height: 40)
                        .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
 
    /// Items of the order and the total.
    private func itemsCard(_ order: Order) -> some View {
        VStack(spacing: 12) {
            ForEach(order.items, id: \.self) { item in
                HStack(spacing: 12) {
                    thumbnail(for: order)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ink)
                        Text("Quantity \(item.quantity)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Text(qar(item.price * Double(item.quantity)))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.ink)
                }
            }
            Divider()
            HStack {
                Text(order.paymentMethod == .payAtPickup ? "To collect at pickup" : "Total paid")
                    .foregroundStyle(Color.muted)
                Spacer()
                Text(qar(order.total))
                    .fontWeight(.heavy)
                    .foregroundStyle(Color.ink)
            }
            .font(.system(size: 14))
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
 
    /// Deal photo if there is one, otherwise an orange box with an icon.
    @ViewBuilder
    private func thumbnail(for order: Order) -> some View {
        if let urlString = model.deal(for: order)?.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brandLight
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandLight)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "fork.knife").foregroundStyle(Color.brand))
        }
    }
 
    /// The customer's note (allergies, "no onions") in a yellow box.
    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Customer notes", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x9A6B0A))
            Text("\u{201C}\(notes)\u{201D}")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFF6DD), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xF1D9A0)))
    }
 
    // MARK: - Pickup code (Figma B8)
 
    private func codeCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Check pickup code", systemImage: "key")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.brandText)
            Text("Ask \(model.customerName(for: order)) for the 4-digit code shown in their app.")
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
 
            // Four boxes. A hidden number field on top collects the digits.
            ZStack {
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { index in
                        let digit = index < code.count ? String(Array(code)[index]) : ""
                        Text(digit)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Color.brandDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                // Orange border on the box being filled
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(index == code.count && codeFocused ? Color.brand : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .focused($codeFocused)
                    .opacity(0.02)
                    .onChange(of: code) { _, newValue in
                        // Keep only numbers, maximum 4
                        let cleaned = String(newValue.filter(\.isNumber).prefix(4))
                        if cleaned != newValue { code = cleaned }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { codeFocused = true }   // tapping the boxes opens the keyboard
 
            // Tells the business right away if the code is right or wrong
            if code.count == 4 {
                if code == order.pickupCode {
                    Label("Code matches order \(orderNumber(for: order))", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1E7A4C))
                } else {
                    Label("That code doesn't match this order", systemImage: "xmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brand, lineWidth: 1.5))
    }
 
    // MARK: - Buttons at the bottom
 
    private func actionBar(_ order: Order) -> some View {
        let matches = code == order.pickupCode   // true when the typed code is the customer's code
        return VStack {
            switch order.status {
            case .new:
                HStack(spacing: 10) {
                    Button("Decline") { showDecline = true }
                        .buttonStyle(SecondaryActionStyle())
                        .frame(width: 110)
                    Button {
                        Task { await move(order, to: .preparing) }
                    } label: {
                        Label("Accept & start preparing", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isWorking)
                }
            case .preparing:
                Button {
                    Task { await move(order, to: .ready) }
                } label: {
                    Label("Mark as ready for pickup", systemImage: "bag")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
            case .ready:
                Button {
                    Task { await move(order, to: .pickedUp) }
                } label: {
                    Label("Confirm pickup", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!matches || isWorking)   // only works when the code matches
                .opacity(matches ? 1 : 0.5)
            case .pickedUp, .cancelled:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }
 
    /// Saves the new status. After pickup, opens the "Order picked up" screen.
    private func move(_ order: Order, to status: OrderStatus) async {
        isWorking = true
        let saved = await model.setStatus(order, to: status)
        isWorking = false
        if saved && status == .pickedUp {
            showCompleted = true
        }
    }
}
 
// MARK: - White button with a border (Decline)
 
struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
    }
}
 
// MARK: - "Order picked up" screen (Figma B9)
 
struct BusinessOrderCompletedView: View {
    @ObservedObject var model: BusinessOrdersViewModel
    let orderId: String
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        let order = model.orders.first { $0.id == orderId }
        let totals = model.pickedUpTotals()
 
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
 
            // Orange check mark
            ZStack {
                Circle().fill(Color.brandLight).frame(width: 120, height: 120)
                Circle().fill(Color.brand).frame(width: 84, height: 84)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
 
            Text("Order picked up")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color.ink)
 
            if let order {
                let title = order.items.first?.title ?? "order"
                Text("\(orderNumber(for: order)) · \(model.customerName(for: order)) collected the \(title).")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
 
            // Totals from all picked-up orders of this store
            HStack(spacing: 12) {
                statBox(icon: "leaf.fill", value: "\(totals.meals)", label: "meals saved so far")
                statBox(icon: "banknote", value: qar(totals.earned), label: "earned from surplus")
            }
 
            Spacer()
 
            Button("Back to orders") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(Color.appBackground)
    }
 
    /// One light orange box with an icon, a number and a label.
    private func statBox(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.brand)
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.brandDark)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.brandDark)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 14))
    }
}
