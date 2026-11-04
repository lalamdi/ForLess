//
//  AuthManager.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Handles phone sign-in with Firebase Authentication:
//  1. sendCode  - checks the form and sends an SMS code
//  2. verify    - checks the code, signs the user in and saves their profile
//  The profile (name, phone, role) is stored in the Firestore "users" collection.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthManager: ObservableObject {
    @Published var isSignedIn = false            // true once the user has verified their code
    @Published var profile: ForLess.User?        // our User struct (ForLess.User avoids a clash with Firebase's User)
    @Published var isLoading = false             // shows a spinner on the buttons
    @Published var errorMessage: String?         // shown in red on the sign-in screens

    private(set) var phoneNumber = ""            // full number, e.g. +97455123480
    private var verificationID: String?          // returned by Firebase after the SMS is sent
    private var pendingName = ""                 // name typed on the sign-in screen
    private var pendingRole: UserRole = .customer
    private let db = Firestore.firestore()

    init() {
        // Lets the Firebase test phone numbers work in the simulator without a real SMS.
        // Remove this line before the app is released.
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true

        // If the user signed in before, skip the sign-in screen and load their profile
        if let current = Auth.auth().currentUser {
            isSignedIn = true
            Task { await loadProfile(uid: current.uid) }
        }
    }

    /// The signed-in user's Firebase ID (used as customerId on orders).
    var uid: String? { Auth.auth().currentUser?.uid }

    /// Step 1: check the form and send the SMS code. Returns true when the code was sent.
    func sendCode(name: String, mobile: String, role: UserRole) async -> Bool {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = mobile.filter(\.isNumber)   // keep only numbers (ignores spaces)

        // Simple checks before contacting Firebase
        guard !trimmedName.isEmpty else {
            errorMessage = role == .business ? "Enter your store name." : "Enter your name."
            return false
        }
        guard digits.count == 8 else {
            errorMessage = "Enter your 8-digit Qatar mobile number."
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let number = "+974" + digits
            // Firebase sends the SMS and gives back an ID we need for step 2
            verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(number, uiDelegate: nil)
            phoneNumber = number
            pendingName = trimmedName
            pendingRole = role
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Step 2: check the 6-digit code, sign in, and save the profile.
    func verify(code: String) async {
        errorMessage = nil
        guard let verificationID else {
            errorMessage = "Please request a new code."
            return
        }
        guard code.count == 6 else {
            errorMessage = "Enter the 6-digit code."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            // Combine the ID from step 1 with the code the user typed
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID,
                                                                     verificationCode: code)
            let result = try await Auth.auth().signIn(with: credential)
            try await saveProfileIfNeeded(uid: result.user.uid)
            isSignedIn = true   // RootView now shows the home screen
        } catch {
            errorMessage = "That code didn't work. Check it and try again."
        }
    }

    /// Signs out and returns to the sign-in screen.
    func signOut() {
        try? Auth.auth().signOut()
        isSignedIn = false
        profile = nil
        verificationID = nil
    }

    /// New users get a profile in the "users" collection. Returning users keep theirs.
    private func saveProfileIfNeeded(uid: String) async throws {
        let ref = db.collection("users").document(uid)
        let snapshot = try await ref.getDocument()

        // Returning user: load the saved profile instead of overwriting it
        if snapshot.exists, var existing = try? snapshot.data(as: ForLess.User.self) {
            existing.id = uid
            profile = existing
            return
        }

        // New user: save name, phone and role (customer or business)
        let newUser = ForLess.User(id: nil, name: pendingName, phone: phoneNumber, role: pendingRole,
                                   savedLocations: [], foodPreferences: [])
        try ref.setData(from: newUser)
        var saved = newUser
        saved.id = uid
        profile = saved
    }

    /// Loads the profile of a user who was already signed in when the app opened.
    private func loadProfile(uid: String) async {
        guard let snapshot = try? await db.collection("users").document(uid).getDocument(),
              var user = try? snapshot.data(as: ForLess.User.self) else { return }
        user.id = uid
        profile = user
    }
}
