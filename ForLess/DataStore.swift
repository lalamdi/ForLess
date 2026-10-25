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
   private func decode<T: FirestoreModel>(_ snapshot: QuerySnapshot, as type: T.Type) -> [T] {
       snapshot.documents.compactMap { document in
           guard var item = try? document.data(as: T.self) else { return nil }
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

   /// A customer's past orders, newest first (used for Order history and Buy again).
   func fetchOrders(customerId: String) async throws -> [Order] {
       let snapshot = try await db.collection(Collection.orders)
           .whereField("customerId", isEqualTo: customerId)
           .getDocuments()
       return decode(snapshot, as: Order.self).sorted { $0.createdAt > $1.createdAt }
   }

   /// Saves a new order and returns its ID.
   func createOrder(_ order: Order) throws -> String {
       let reference = try db.collection(Collection.orders).addDocument(from: order)
       return reference.documentID
   }

   /// Moves an order along: new -> preparing -> ready -> pickedUp (used by the business side).
   func updateOrderStatus(orderId: String, to status: OrderStatus) async throws {
       try await db.collection(Collection.orders)
           .document(orderId)
           .updateData(["status": status.rawValue])
   }

   // MARK: - Users

   /// Saves a user under their Firebase Auth user ID.
   func saveUser(_ user: User, uid: String) throws {
       try db.collection(Collection.users).document(uid).setData(from: user)
   }

   // MARK: - Used by the test screen

   func loadAll() async {
       do {
           stores = try await fetchStores()
           deals = try await fetchAllDeals()
           errorMessage = nil
       } catch {
           errorMessage = error.localizedDescription
       }
   }

   // MARK: - Sample data (matches the Figma prototype)

   /// Writes sample stores, deals, users and orders. Safe to run more than once:
   /// it uses fixed IDs, so it overwrites instead of making duplicates.
   func addSampleData() async {
       let calendar = Calendar.current
       let today = calendar.startOfDay(for: Date())
       func time(_ hour: Int, _ minute: Int = 0, daysFromToday days: Int = 0) -> Date {
           let day = calendar.date(byAdding: .day, value: days, to: today)!
           return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
       }

       let sampleStores: [(String, Store)] = [
           ("zaatar-w-zeit", Store(id: nil, googlePlaceId: nil, name: "Za'atar W Zeit", type: .restaurant,
                                   address: "Education City, Doha", latitude: 25.3141, longitude: 51.4396,
                                   rating: 4.6, photoURL: nil, ownerId: "zaatar-owner")),
           ("coffee-bean", Store(id: nil, googlePlaceId: nil, name: "The Coffee Bean & Tea Leaf", type: .restaurant,
                                 address: "Education City, Doha", latitude: 25.3160, longitude: 51.4410,
                                 rating: 4.4, photoURL: nil, ownerId: nil)),
           ("harvest", Store(id: nil, googlePlaceId: nil, name: "Harvest", type: .restaurant,
                             address: "Education City, Doha", latitude: 25.3120, longitude: 51.4370,
                             rating: 4.7, photoURL: nil, ownerId: nil)),
           ("green-basket", Store(id: nil, googlePlaceId: nil, name: "Green Basket Market", type: .grocery,
                                  address: "Education City, Doha", latitude: 25.3150, longitude: 51.4420,
                                  rating: 4.5, photoURL: nil, ownerId: nil))
       ]

       let sampleDeals: [(String, Deal)] = [
           ("chicken-caesar-wrap", Deal(id: nil, storeId: "zaatar-w-zeit", title: "Chicken Caesar Wrap",
                                        description: "Grilled chicken, romaine, parmesan and Caesar dressing",
                                        photoURL: nil, kind: .meal, originalPrice: 32, dealPrice: 20, quantityLeft: 3,
                                        pickupStart: time(17), pickupEnd: time(19), expiryDate: nil)),
           ("breaded-chicken", Deal(id: nil, storeId: "zaatar-w-zeit", title: "Breaded Chicken",
                                    description: "Crispy chicken with garlic sauce",
                                    photoURL: nil, kind: .meal, originalPrice: 28, dealPrice: 18, quantityLeft: 5,
                                    pickupStart: time(17), pickupEnd: time(19), expiryDate: nil)),
           ("labneh-wrap", Deal(id: nil, storeId: "zaatar-w-zeit", title: "Labneh Wrap",
                                description: "Labneh, cucumber, mint, olives",
                                photoURL: nil, kind: .meal, originalPrice: 19, dealPrice: 12, quantityLeft: 2,
                                pickupStart: time(17), pickupEnd: time(19), expiryDate: nil)),
           ("iced-latte-muffin", Deal(id: nil, storeId: "coffee-bean", title: "Iced Latte + Muffin",
                                      description: "Any iced latte with a blueberry muffin",
                                      photoURL: nil, kind: .meal, originalPrice: 26, dealPrice: 14, quantityLeft: 4,
                                      pickupStart: time(18), pickupEnd: time(20), expiryDate: nil)),
           ("veggie-flatbread", Deal(id: nil, storeId: "harvest", title: "Veggie Flatbread",
                                     description: "Roasted vegetables, feta, herbs",
                                     photoURL: nil, kind: .meal, originalPrice: 26, dealPrice: 15, quantityLeft: 3,
                                     pickupStart: time(19), pickupEnd: time(21), expiryDate: nil)),
           ("mixed-fruit-box", Deal(id: nil, storeId: "green-basket", title: "Mixed Fruit Box",
                                    description: "1.5 kg: apples, bananas, oranges, grapes, pears",
                                    photoURL: nil, kind: .grocery, originalPrice: 38, dealPrice: 22, quantityLeft: 4,
                                    pickupStart: time(16), pickupEnd: time(20), expiryDate: time(23, 59, daysFromToday: 2))),
           ("greek-yogurt", Deal(id: nil, storeId: "green-basket", title: "Greek Yogurt",
                                 description: "4 × 150 g, plain",
                                 photoURL: nil, kind: .grocery, originalPrice: 19, dealPrice: 11, quantityLeft: 6,
                                 pickupStart: time(16), pickupEnd: time(20), expiryDate: time(23, 59, daysFromToday: 7))),
           ("whole-milk", Deal(id: nil, storeId: "green-basket", title: "Whole Milk",
                               description: "2 L",
                               photoURL: nil, kind: .grocery, originalPrice: 12, dealPrice: 7, quantityLeft: 5,
                               pickupStart: time(16), pickupEnd: time(20), expiryDate: time(23, 59, daysFromToday: 3)))
       ]

       let sampleUsers: [(String, User)] = [
           ("aisha", User(id: nil, name: "Aisha Al-Kuwari", phone: "+97455123480", role: .customer,
                          savedLocations: [
                              SavedLocation(label: "Home", address: "Education City, Doha", latitude: 25.3141, longitude: 51.4396),
                              SavedLocation(label: "Work", address: "West Bay, Doha", latitude: 25.3240, longitude: 51.5310)
                          ],
                          foodPreferences: ["Pizza", "Wraps", "Bakery"])),
           ("zaatar-owner", User(id: nil, name: "Za'atar W Zeit", phone: "+97444127788", role: .business,
                                 savedLocations: [], foodPreferences: []))
       ]

       let sampleOrders: [(String, Order)] = [
           ("FL-2041", Order(id: nil, customerId: "aisha", storeId: "zaatar-w-zeit",
                             items: [OrderItem(dealId: "chicken-caesar-wrap", title: "Chicken Caesar Wrap", quantity: 1, price: 20)],
                             total: 20, paymentMethod: .applePay, status: .new, pickupCode: "4821",
                             notes: "No onions please. I'm allergic to nuts.", createdAt: time(16, 50))),
           ("FL-2042", Order(id: nil, customerId: "aisha", storeId: "green-basket",
                             items: [OrderItem(dealId: "mixed-fruit-box", title: "Mixed Fruit Box", quantity: 1, price: 22)],
                             total: 22, paymentMethod: .applePay, status: .pickedUp, pickupCode: "5307",
                             notes: nil, createdAt: time(17, 10, daysFromToday: -2))),
           ("FL-2036", Order(id: nil, customerId: "aisha", storeId: "coffee-bean",
                             items: [OrderItem(dealId: "iced-latte-muffin", title: "Iced Latte + Muffin", quantity: 1, price: 14)],
                             total: 14, paymentMethod: .payAtPickup, status: .pickedUp, pickupCode: "2290",
                             notes: nil, createdAt: time(18, 30, daysFromToday: -5)))
       ]

       do {
           for (id, store) in sampleStores {
               try db.collection(Collection.stores).document(id).setData(from: store)
           }
           for (id, deal) in sampleDeals {
               try db.collection(Collection.deals).document(id).setData(from: deal)
           }
           for (id, user) in sampleUsers {
               try db.collection(Collection.users).document(id).setData(from: user)
           }
           for (id, order) in sampleOrders {
               try db.collection(Collection.orders).document(id).setData(from: order)
           }
           await loadAll()
       } catch {
           errorMessage = error.localizedDescription
       }
   }
}
