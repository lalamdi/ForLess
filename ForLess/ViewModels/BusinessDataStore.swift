//
//  BusinessDataStore.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//



//  Extra DataStore functions for the business side.
 
import Foundation
import FirebaseFirestore
 
extension DataStore {
 
    /// The store that belongs to this business user (the store's ownerId is the user's ID).
    func fetchStore(ownerId: String) async throws -> Store? {
        let snapshot = try await Firestore.firestore().collection("stores")
            .whereField("ownerId", isEqualTo: ownerId)
            .limit(to: 1)
            .getDocuments()
        guard let document = snapshot.documents.first,
              var store = try? document.data(as: Store.self) else { return nil }
        store.id = document.documentID
        return store
    }
 
    /// All orders of one store, newest first.
    func fetchOrders(storeId: String) async throws -> [Order] {
        let snapshot = try await Firestore.firestore().collection("orders")
            .whereField("storeId", isEqualTo: storeId)
            .getDocuments()
        let orders: [Order] = snapshot.documents.compactMap { document in
            guard var order = try? document.data(as: Order.self) else { return nil }
            order.id = document.documentID
            return order
        }
        return orders.sorted { $0.createdAt > $1.createdAt }
    }
 
    /// One user's profile (used to show the customer's name and phone).
    func fetchUser(uid: String) async throws -> User? {
        let document = try await Firestore.firestore().collection("users").document(uid).getDocument()
        guard var user = try? document.data(as: User.self) else { return nil }
        user.id = document.documentID
        return user
    }
 
    /// One deal (used to show the pickup time and photo).
    func fetchDeal(dealId: String) async throws -> Deal? {
        let document = try await Firestore.firestore().collection("deals").document(dealId).getDocument()
        guard var deal = try? document.data(as: Deal.self) else { return nil }
        deal.id = document.documentID
        return deal
    }
}
