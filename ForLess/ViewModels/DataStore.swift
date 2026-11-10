//
//  DataStore.swift
//  ForLess
//
//  Created by lama alemadi on 25/10/2026.
//


import Foundation
import FirebaseFirestore
import Combine

/// Any model saved in Firestore. The document ID is copied into `id` when we read it.
protocol FirestoreModel: Codable {
    var id: String? { get set }
}

extension User: FirestoreModel {}
extension Store: FirestoreModel {}
extension Deal: FirestoreModel {}
extension Order: FirestoreModel {}

@MainActor
final class DataStore: ObservableObject {

    private let db = Firestore.firestore()

    @Published var stores: [Store] = []
    @Published var deals: [Deal] = []
    @Published var errorMessage: String?

    // Collection names in Firestore
    private enum Collection {
        static let users = "users"
        static let stores = "stores"
        static let deals = "deals"
        static let orders = "orders"
    }

    // MARK: - Helpers

    /// Turns Firestore documents into our Swift structs.
    private func decode<T: FirestoreModel>(
        _ snapshot: QuerySnapshot,
        as type: T.Type
    ) -> [T] {
        snapshot.documents.compactMap { document in
            guard var item = try? document.data(as: T.self) else {
                return nil
            }

            item.id = document.documentID
            return item
        }
    }

    // MARK: - Stores

    func fetchStores() async throws -> [Store] {
        let snapshot = try await db.collection(Collection.stores).getDocuments()
        return decode(snapshot, as: Store.self)
    }

    // MARK: - Deals

    /// All deals for one store (restaurant or grocery).
    func fetchDeals(storeId: String) async throws -> [Deal] {
        let snapshot = try await db.collection(Collection.deals)
            .whereField("storeId", isEqualTo: storeId)
            .getDocuments()

        return decode(snapshot, as: Deal.self)
    }

    func fetchAllDeals() async throws -> [Deal] {
        let snapshot = try await db.collection(Collection.deals).getDocuments()
        return decode(snapshot, as: Deal.self)
    }

    // MARK: - Orders

    /// A customer's past orders, newest first.
    func fetchOrders(customerId: String) async throws -> [Order] {
        let snapshot = try await db.collection(Collection.orders)
            .whereField("customerId", isEqualTo: customerId)
            .getDocuments()

        return decode(snapshot, as: Order.self)
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Saves a new order and returns its ID.
    func createOrder(_ order: Order) throws -> String {
        let reference = try db.collection(Collection.orders)
            .addDocument(from: order)

        return reference.documentID
    }

    /// Moves an order along: new -> preparing -> ready -> pickedUp.
    func updateOrderStatus(
        orderId: String,
        to status: OrderStatus
    ) async throws {
        try await db.collection(Collection.orders)
            .document(orderId)
            .updateData(["status": status.rawValue])
    }

    /// Lowers the available quantity of a deal after an order.
    func reduceQuantity(dealId: String, by amount: Int) {
        db.collection(Collection.deals)
            .document(dealId)
            .updateData([
                "quantityLeft": FieldValue.increment(Int64(-amount))
            ])
    }

    // MARK: - Users

    /// Saves a user under their Firebase Auth user ID.
    func saveUser(_ user: User, uid: String) throws {
        try db.collection(Collection.users)
            .document(uid)
            .setData(from: user)
    }

    // MARK: - Load data

    func loadAll() async {
        do {
            // Load the stores and the deals at the same time (faster)
            async let loadedStores = fetchStores()
            async let loadedDeals = fetchAllDeals()
            stores = try await loadedStores
            deals = try await loadedDeals
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Expired sample deals

    /// Sample grocery deals that already expired get a new expiry date
    /// (this month and next). It runs once on this phone.
    func fixSampleExpiryDates() async {
        if UserDefaults.standard.bool(forKey: "didFixSampleExpiry") { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // deal ID and how many days from today
        let newExpiry = [
            "mixed-fruit-box": 11,
            "whole-milk": 21,
            "greek-yogurt": 31
        ]

        for (id, days) in newExpiry {
            let ref = db.collection(Collection.deals).document(id)
            guard let snapshot = try? await ref.getDocument(), snapshot.exists else { continue }

            // Only deals that are already expired
            let current = (snapshot.data()?["expiryDate"] as? Timestamp)?.dateValue()
            guard let current, current < Date() else { continue }

            let day = calendar.date(byAdding: .day, value: days, to: today)!
            let newDate = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)!
            try? await ref.updateData(["expiryDate": Timestamp(date: newDate)])
        }

        UserDefaults.standard.set(true, forKey: "didFixSampleExpiry")
    }

    // MARK: - Sample photos

    /// Adds a photo link to the sample stores and deals that do not have one.
    /// It only fills an empty photoURL, so nothing else is changed.
    func addSamplePhotos() async {
        let storePhotos = [
            "zaatar-w-zeit": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
            "coffee-bean": "https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=800",
            "harvest": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800",
            "green-basket": "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800"
        ]
        let dealPhotos = [
            "chicken-caesar-wrap": "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=800",
            "breaded-chicken": "https://images.unsplash.com/photo-1562967914-608f82629710?w=800",
            "labneh-wrap": "https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800",
            "iced-latte-muffin": "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=800",
            "veggie-flatbread": "https://images.unsplash.com/photo-1579751626657-72bc17010498?w=800",
            "mixed-fruit-box": "https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800",
            "greek-yogurt": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800",
            "whole-milk": "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=800"
        ]

        await fillPhotos(storePhotos, in: Collection.stores)
        await fillPhotos(dealPhotos, in: Collection.deals)
    }

    private func fillPhotos(_ photos: [String: String], in collection: String) async {
        for (id, url) in photos {
            let ref = db.collection(collection).document(id)
            guard let snapshot = try? await ref.getDocument(), snapshot.exists else { continue }
            let current = snapshot.data()?["photoURL"] as? String ?? ""
            if current.isEmpty {
                try? await ref.updateData(["photoURL": url])
            }
        }
    }

    // MARK: - Sample data

    /// Writes sample stores, deals, users and orders.
    /// Uses fixed IDs, so running it again overwrites existing sample documents.

    func addSampleData() async {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func time(
            _ hour: Int,
            _ minute: Int = 0,
            daysFromToday days: Int = 0
        ) -> Date {
            let day = calendar.date(
                byAdding: .day,
                value: days,
                to: today
            )!

            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: day
            )!
        }

        // MARK: Sample stores

        let sampleStores: [(String, Store)] = [

            ("zaatar-w-zeit", Store(
                id: nil,
                googlePlaceId: nil,
                name: "Za'atar W Zeit",
                type: .restaurant,
                address: "Education City, Doha",
                latitude: 25.3141,
                longitude: 51.4396,
                rating: 4.6,
                photoURL: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
                ownerId: "zaatar-owner"
            )),

            ("coffee-bean", Store(
                id: nil,
                googlePlaceId: nil,
                name: "The Coffee Bean & Tea Leaf",
                type: .restaurant,
                address: "Education City, Doha",
                latitude: 25.3160,
                longitude: 51.4410,
                rating: 4.4,
                photoURL: "https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=800",
                ownerId: nil
            )),

            ("harvest", Store(
                id: nil,
                googlePlaceId: nil,
                name: "Harvest",
                type: .restaurant,
                address: "Education City, Doha",
                latitude: 25.3120,
                longitude: 51.4370,
                rating: 4.7,
                photoURL: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800",
                ownerId: nil
            )),

            ("green-basket", Store(
                id: nil,
                googlePlaceId: nil,
                name: "Green Basket Market",
                type: .grocery,
                address: "Education City, Doha",
                latitude: 25.3150,
                longitude: 51.4420,
                rating: 4.5,
                photoURL: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
                ownerId: nil
            ))
        ]

        // MARK: Sample deals

        let sampleDeals: [(String, Deal)] = [

            ("chicken-caesar-wrap", Deal(
                id: nil,
                storeId: "zaatar-w-zeit",
                title: "Chicken Caesar Wrap",
                description: "Grilled chicken, romaine, parmesan and Caesar dressing",
                photoURL: "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=800",
                kind: .meal,
                originalPrice: 32,
                dealPrice: 20,
                quantityLeft: 3,
                pickupStart: time(17),
                pickupEnd: time(19),
                expiryDate: nil
            )),

            ("breaded-chicken", Deal(
                id: nil,
                storeId: "zaatar-w-zeit",
                title: "Breaded Chicken",
                description: "Crispy chicken with garlic sauce",
                photoURL: "https://images.unsplash.com/photo-1562967914-608f82629710?w=800",
                kind: .meal,
                originalPrice: 28,
                dealPrice: 18,
                quantityLeft: 5,
                pickupStart: time(17),
                pickupEnd: time(19),
                expiryDate: nil
            )),

            ("labneh-wrap", Deal(
                id: nil,
                storeId: "zaatar-w-zeit",
                title: "Labneh Wrap",
                description: "Labneh, cucumber, mint, olives",
                photoURL: "https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800",
                kind: .meal,
                originalPrice: 19,
                dealPrice: 12,
                quantityLeft: 2,
                pickupStart: time(17),
                pickupEnd: time(19),
                expiryDate: nil
            )),

            ("iced-latte-muffin", Deal(
                id: nil,
                storeId: "coffee-bean",
                title: "Iced Latte + Muffin",
                description: "Any iced latte with a blueberry muffin",
                photoURL: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=800",
                kind: .meal,
                originalPrice: 26,
                dealPrice: 14,
                quantityLeft: 4,
                pickupStart: time(18),
                pickupEnd: time(20),
                expiryDate: nil
            )),

            ("veggie-flatbread", Deal(
                id: nil,
                storeId: "harvest",
                title: "Veggie Flatbread",
                description: "Roasted vegetables, feta, herbs",
                photoURL: "https://images.unsplash.com/photo-1579751626657-72bc17010498?w=800",
                kind: .meal,
                originalPrice: 26,
                dealPrice: 15,
                quantityLeft: 3,
                pickupStart: time(19),
                pickupEnd: time(21),
                expiryDate: nil
            )),

            ("mixed-fruit-box", Deal(
                id: nil,
                storeId: "green-basket",
                title: "Mixed Fruit Box",
                description: "1.5 kg: apples, bananas, oranges, grapes, pears",
                photoURL: "https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800",
                kind: .grocery,
                originalPrice: 38,
                dealPrice: 22,
                quantityLeft: 4,
                pickupStart: time(16),
                pickupEnd: time(20),
                expiryDate: time(23, 59, daysFromToday: 11)
            )),

            ("greek-yogurt", Deal(
                id: nil,
                storeId: "green-basket",
                title: "Greek Yogurt",
                description: "4 × 150 g, plain",
                photoURL: "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800",
                kind: .grocery,
                originalPrice: 19,
                dealPrice: 11,
                quantityLeft: 6,
                pickupStart: time(16),
                pickupEnd: time(20),
                expiryDate: time(23, 59, daysFromToday: 31)
            )),

            ("whole-milk", Deal(
                id: nil,
                storeId: "green-basket",
                title: "Whole Milk",
                description: "2 L",
                photoURL: "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=800",
                kind: .grocery,
                originalPrice: 12,
                dealPrice: 7,
                quantityLeft: 5,
                pickupStart: time(16),
                pickupEnd: time(20),
                expiryDate: time(23, 59, daysFromToday: 21)
            ))
        ]

        // MARK: Sample users

        let sampleUsers: [(String, User)] = [

            ("aisha", User(
                id: nil,
                name: "Aisha Al-Kuwari",
                phone: "+97455123480",
                role: .customer,
                savedLocations: [
                    SavedLocation(
                        label: "Home",
                        address: "Education City, Doha",
                        latitude: 25.3141,
                        longitude: 51.4396
                    ),
                    SavedLocation(
                        label: "Work",
                        address: "West Bay, Doha",
                        latitude: 25.3240,
                        longitude: 51.5310
                    )
                ],
                foodPreferences: ["Pizza", "Wraps", "Bakery"]
            )),

            ("zaatar-owner", User(
                id: nil,
                name: "Za'atar W Zeit",
                phone: "+97444127788",
                role: .business,
                savedLocations: [],
                foodPreferences: []
            ))
        ]

        // MARK: Sample orders

        let sampleOrders: [(String, Order)] = [

            ("FL-2041", Order(
                id: nil,
                customerId: "aisha",
                storeId: "zaatar-w-zeit",
                items: [
                    OrderItem(
                        dealId: "chicken-caesar-wrap",
                        title: "Chicken Caesar Wrap",
                        quantity: 1,
                        price: 20
                    )
                ],
                total: 20,
                paymentMethod: .applePay,
                status: .new,
                pickupCode: "4821",
                notes: "No onions please. I'm allergic to nuts.",
                createdAt: time(16, 50)
            )),

            ("FL-2042", Order(
                id: nil,
                customerId: "aisha",
                storeId: "green-basket",
                items: [
                    OrderItem(
                        dealId: "mixed-fruit-box",
                        title: "Mixed Fruit Box",
                        quantity: 1,
                        price: 22
                    )
                ],
                total: 22,
                paymentMethod: .applePay,
                status: .pickedUp,
                pickupCode: "5307",
                notes: nil,
                createdAt: time(17, 10, daysFromToday: -2)
            )),

            ("FL-2036", Order(
                id: nil,
                customerId: "aisha",
                storeId: "coffee-bean",
                items: [
                    OrderItem(
                        dealId: "iced-latte-muffin",
                        title: "Iced Latte + Muffin",
                        quantity: 1,
                        price: 14
                    )
                ],
                total: 14,
                paymentMethod: .payAtPickup,
                status: .pickedUp,
                pickupCode: "2290",
                notes: nil,
                createdAt: time(18, 30, daysFromToday: -5)
            ))
        ]

        // MARK: Save sample data

        do {
            for (id, store) in sampleStores {
                try db.collection(Collection.stores)
                    .document(id)
                    .setData(from: store)
            }

            for (id, deal) in sampleDeals {
                try db.collection(Collection.deals)
                    .document(id)
                    .setData(from: deal)
            }

            for (id, user) in sampleUsers {
                try db.collection(Collection.users)
                    .document(id)
                    .setData(from: user)
            }

            for (id, order) in sampleOrders {
                try db.collection(Collection.orders)
                    .document(id)
                    .setData(from: order)
            }

            await loadAll()

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Deal {
    /// True when a grocery deal is past its expiry date.
    var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }
}
