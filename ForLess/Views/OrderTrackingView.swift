//
//
//  OrderTrackingView.swift
//  ForLess
//
//  Created by H A on 07/11/2026.
//

import SwiftUI
import FirebaseFirestore

struct OrderTrackingView: View {

    // MARK: - Properties

    let order: Order
    let storeName: String
    let storeAddress: String

    @State private var currentStatus: OrderStatus
    @State private var listener: ListenerRegistration?
    @State private var showThankYou = false
    @State private var goHomeAfterThankYou = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.switchTab) private var switchTab

    init(
        order: Order,
        storeName: String,
        storeAddress: String
    ) {
        self.order = order
        self.storeName = storeName
        self.storeAddress = storeAddress
        _currentStatus = State(initialValue: order.status)
    }

    // MARK: - Timeline Steps

    private let steps: [
        (status: OrderStatus, title: String, description: String, icon: String)
    ] = [
        (.new, "Order placed", "Your order has been received.", "checkmark"),
        (.preparing, "Preparing your order", "The store is getting your items ready.", "takeoutbag.and.cup.and.straw"),
        (.ready, "Ready for pickup", "Your order is ready. Head to the store!", "bag"),
        (.pickedUp, "Picked up", "Enjoy your rescued food!", "checkmark.circle.fill")
    ]

    private var currentStepIndex: Int {
        switch currentStatus {
        case .new:
            return 0
        case .preparing:
            return 1
        case .ready:
            return 2
        case .pickedUp:
            return 3
        case .cancelled:
            return -1
        }
    }

    // MARK: - Main View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                Text("Track your order")
                    .font(.system(size: 27, weight: .heavy))
                    .foregroundStyle(Color.ink)

                if currentStatus == .cancelled {
                    cancelledMessage
                } else {
                    pickupCodeCard
                    timelineSection
                    storeCard
                    orderSummary
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("Order tracking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
        }
        .onDisappear {
            // Keep listening while the thank-you screen is open on top.
            if !showThankYou {
                listener?.remove()
                listener = nil
            }
        }
        // Thank-you screen (Figma 11 / 19) once the store marks the order as picked up
        .fullScreenCover(
            isPresented: $showThankYou,
            onDismiss: {
                // Runs after the thank-you screen has fully closed.
                dismiss()                  // leave the tracking screen (back to Orders)
                if goHomeAfterThankYou {
                    switchTab(0)           // "Back to home" also switches to the Home tab
                }
            }
        ) {
            ThankYouView(
                order: order,
                onBackToHome: {
                    goHomeAfterThankYou = true
                    showThankYou = false
                },
                onViewHistory: {
                    goHomeAfterThankYou = false
                    showThankYou = false
                }
            )
        }
    }

    // MARK: - Pickup Code

    private var pickupCodeCard: some View {
        VStack(spacing: 12) {

            Image(systemName: "ticket")
                .font(.system(size: 28))
                .foregroundStyle(Color.brand)

            Text("Your pickup code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.muted)

            Text(order.pickupCode)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .tracking(6)
                .foregroundStyle(Color.brandDark)

            Text("Show this code when collecting your order.")
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            Color.brandLight,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Order Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("Order progress")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.ink)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in

                let isCompleted = index <= currentStepIndex
                let isCurrent = index == currentStepIndex

                HStack(alignment: .top, spacing: 14) {

                    VStack(spacing: 0) {

                        Image(systemName: isCompleted ? "checkmark" : step.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                isCompleted ? Color.white : Color.muted
                            )
                            .frame(width: 34, height: 34)
                            .background(
                                isCompleted ? Color.brand : Color.line,
                                in: Circle()
                            )

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(
                                    index < currentStepIndex
                                    ? Color.brand
                                    : Color.line
                                )
                                .frame(width: 2, height: 38)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {

                        Text(step.title)
                            .font(
                                .system(
                                    size: 15,
                                    weight: isCurrent ? .bold : .semibold
                                )
                            )
                            .foregroundStyle(
                                isCompleted ? Color.ink : Color.muted
                            )

                        Text(step.description)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.muted)

                        if isCurrent {
                            Text("CURRENT STATUS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.brand)
                                .padding(.top, 3)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(18)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Store Information

    private var storeCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Pickup location")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.ink)

            Label(storeName, systemImage: "storefront")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ink)

            Label(storeAddress, systemImage: "mappin.and.ellipse")
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)

            Divider()

            Text("Order date")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ink)

            Text(
                order.createdAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.system(size: 13))
            .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Order Summary

    private var orderSummary: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Order summary")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.ink)

            ForEach(Array(order.items.enumerated()), id: \.offset) { _, item in

                HStack {
                    Text("\(item.quantity) × \(item.title)")
                        .foregroundStyle(Color.ink)

                    Spacer()

                    Text(qar(item.price * Double(item.quantity)))
                        .foregroundStyle(Color.ink)
                }
                .font(.system(size: 13))
            }

            Divider()

            HStack {
                Text("Total")
                    .fontWeight(.bold)

                Spacer()

                Text(qar(order.total))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandDark)
            }
            .foregroundStyle(Color.ink)

            Text("Payment: \(order.paymentMethod.title)")
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
        }
        .padding(18)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Cancelled Order

    private var cancelledMessage: some View {
        VStack(spacing: 12) {

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Order cancelled")
                .font(.title2.bold())
                .foregroundStyle(Color.ink)

            Text("This order has been cancelled.")
                .font(.subheadline)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    // MARK: - Live Firestore Updates

    private func startListening() {

        guard listener == nil,
              let orderID = order.id else {
            return
        }

        listener = Firestore.firestore()
            .collection("orders")
            .document(orderID)
            .addSnapshotListener { snapshot, error in

                guard error == nil,
                      let data = snapshot?.data(),
                      let statusString = data["status"] as? String,
                      let updatedStatus = OrderStatus(rawValue: statusString)
                else {
                    return
                }

                DispatchQueue.main.async {
                    // Open the thank-you screen when the order changes to picked up.
                    if updatedStatus == .pickedUp && currentStatus != .pickedUp {
                        showThankYou = true
                    }
                    currentStatus = updatedStatus
                }
            }
    }
}
