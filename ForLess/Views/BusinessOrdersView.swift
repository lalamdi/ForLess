//
//  BusinessOrdersView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Business orders
//  the list of the store's orders with All / New / Preparing / Ready filters.
//  Tapping an order opens BusinessOrderDetailView
//
 
import SwiftUI
 
struct BusinessOrdersView: View {
    @EnvironmentObject private var auth: AuthManager          // used for the user's ID
    @StateObject private var model = BusinessOrdersViewModel()
    @State private var filter: OrderFilter = .all
 
    /// The filter chips at the top of the screen.
    enum OrderFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case new = "New"
        case preparing = "Preparing"
        case ready = "Ready"
 
        var id: String { rawValue }
 
        /// The order status this chip shows (nil = all active orders).
        var status: OrderStatus? {
            switch self {
            case .all: return nil
            case .new: return .new
            case .preparing: return .preparing
            case .ready: return .ready
            }
        }
    }
 
    private var visibleOrders: [Order] {
        guard let status = filter.status else { return model.activeOrders }
        return model.orders.filter { $0.status == status }
    }
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    filterChips
 
                    if let error = model.errorMessage {
                        errorCard(error)
                    } else if model.isLoading && model.orders.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if visibleOrders.isEmpty {
                        Text("No orders here yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
 
                    ForEach(visibleOrders) { order in
                        NavigationLink {
                            BusinessOrderDetailView(model: model, orderId: order.id ?? "")
                        } label: {
                            orderCard(order)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await reload() }   // pull down to refresh
            .task { await reload() }
        }
    }
 
    private func reload() async {
        guard let uid = auth.uid else { return }
        await model.load(ownerId: uid)
    }
 
    // MARK: - Pieces of the screen
 
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Orders")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color.ink)
            Text("\(model.store?.name ?? "Your store") · \(model.activeOrders.count) active orders")
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
        }
    }
 
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OrderFilter.allCases) { option in
                    let title = chipTitle(option)
                    Button {
                        filter = option
                    } label: {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(filter == option ? Color.white : Color.ink)
                            .background(filter == option ? Color.ink : Color.white, in: Capsule())
                            .overlay(Capsule().stroke(Color.line))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
 
    /// "All", "New 2", "Preparing 1", ...
    private func chipTitle(_ option: OrderFilter) -> String {
        guard let status = option.status else { return option.rawValue }
        return "\(option.rawValue) \(model.count(status))"
    }
 
    private func orderCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(model.customerName(for: order))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(orderNumber(for: order))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                Spacer()
                StatusBadge(status: order.status)
            }
 
            HStack {
                Text(order.items.map { "\($0.title) × \($0.quantity)" }.joined(separator: ", "))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Spacer()
                Text(qar(order.total))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.ink)
            }
 
            HStack(spacing: 8) {
                Label(model.pickupText(for: order), systemImage: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandText)
                if let notes = order.notes, !notes.isEmpty {
                    Label("Note", systemImage: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Color(hex: 0x9A6B0A))
                        .background(Color(hex: 0xFCEBC8), in: Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
 
    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
}
 
// MARK: - Status badge (New / Preparing / Ready ...)
 
/// Text shown for each order status on the business side.
extension OrderStatus {
    var businessLabel: String {
        switch self {
        case .new: return "New"
        case .preparing: return "Preparing"
        case .ready: return "Ready"
        case .pickedUp: return "Picked up"
        case .cancelled: return "Cancelled"
        }
    }
 
    var badgeTextColor: Color {
        switch self {
        case .new: return Color(hex: 0xC0392B)
        case .preparing: return Color(hex: 0x2F5D9E)
        case .ready: return Color(hex: 0x9A6B0A)
        case .pickedUp: return Color(hex: 0x1E7A4C)
        case .cancelled: return Color.muted
        }
    }
 
    var badgeBackground: Color {
        switch self {
        case .new: return Color(hex: 0xFDE8E6)
        case .preparing: return Color(hex: 0xE3EEFB)
        case .ready: return Color(hex: 0xFCEBC8)
        case .pickedUp: return Color(hex: 0xDDF3E7)
        case .cancelled: return Color.line
        }
    }
}
 
/// The small colored pill with the status text.
struct StatusBadge: View {
    let status: OrderStatus
 
    var body: some View {
        Text(status.businessLabel)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(status.badgeTextColor)
            .background(status.badgeBackground, in: Capsule())
    }
}
