//
//  Models.swift
//  ForLess
//
//  Created by lama alemadi on 24/10/2026.
//

import Foundation

// MARK: - User

enum UserRole: String, Codable {
    case customer
    case business
}

struct SavedLocation: Codable, Hashable {
    var label: String          // "Home", "Work"
    var address: String        // "Education City, Doha"
    var latitude: Double
    var longitude: Double
}

struct User: Codable, Identifiable {
    var id: String?
    var name: String
    var phone: String
    var role: UserRole
    var savedLocations: [SavedLocation]
    var foodPreferences: [String]
}

// MARK: - Store

enum StoreType: String, Codable {
    case restaurant
    case grocery
}

struct Store: Codable, Identifiable {
    var id: String?
    var googlePlaceId: String?
    var name: String
    var type: StoreType
    var address: String
    var latitude: Double
    var longitude: Double
    var rating: Double?
    var photoURL: String?
    var ownerId: String?
}

// MARK: - Deal

enum DealKind: String, Codable {
    case meal
    case grocery
}

struct Deal: Codable, Identifiable {
    var id: String?
    var storeId: String
    var title: String
    var description: String
    var photoURL: String?
    var kind: DealKind
    var originalPrice: Double
    var dealPrice: Double
    var quantityLeft: Int
    var pickupStart: Date
    var pickupEnd: Date
    var expiryDate: Date?      // groceries only

    var discountPercent: Int {
        guard originalPrice > 0 else { return 0 }
        return Int(((originalPrice - dealPrice) / originalPrice * 100).rounded())
    }
}

// MARK: - Order

enum OrderStatus: String, Codable {
    case new
    case preparing
    case ready
    case pickedUp
}

enum PaymentMethod: String, Codable {
    case applePay
    case card
    case payAtPickup
}

struct OrderItem: Codable, Hashable {
    var dealId: String
    var title: String
    var quantity: Int
    var price: Double
}

struct Order: Codable, Identifiable {
    var id: String?
    var customerId: String
    var storeId: String
    var items: [OrderItem]
    var total: Double
    var paymentMethod: PaymentMethod
    var status: OrderStatus
    var pickupCode: String
    var notes: String?
    var createdAt: Date
}
