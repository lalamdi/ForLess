//
//  AuthManager.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Handles sign-in with Firebase Authentication:
//  - logIn      - username + password (every time after the first)
//  - sendCode   - first time only: checks the form and sends an SMS code
//  - verify     - checks the code, adds the username + password to the account
//                 and saves the profile
//  The username is turned into a hidden email (name@forless.app) because
//  Firebase logs in with email + password. The profile (name, phone, role,
//  username) is stored in the Firestore "users" collection.
//

import Foundation
import UIKit
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
    private var pendingUsername = ""             // chosen username (saved after the SMS code)
    private var pendingPassword = ""
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

    /// Hidden email Firebase uses for a username, e.g. lama_a becomes lama_a@forless.app
    private static func email(for username: String) -> String {
        username + "@forless.app"
    }

    /// Log in with username + password.
    func logIn(username: String, password: String, role: UserRole) async {
        errorMessage = nil
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your username and password."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: Self.email(for: name), password: password)
            let snapshot = try await db.collection("users").document(result.user.uid).getDocument()
            guard var user = try? snapshot.data(as: ForLess.User.self) else {
                try? Auth.auth().signOut()
                errorMessage = "We couldn't load this account."
                return
            }
            // The Customer / Business tab has to match the account
            if user.role != role {
                try? Auth.auth().signOut()
                errorMessage = role == .customer
                    ? "This is a business account. Use the Business tab."
                    : "This is a customer account. Use the Customer tab."
                return
            }
            user.id = result.user.uid
            profile = user
            isSignedIn = true
        } catch {
            // 17004, 17009 and 17011 are Firebase's wrong password / unknown user codes
            let code = (error as NSError).code
            if [17004, 17009, 17011].contains(code) {
                errorMessage = "Wrong username or password."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Step 1 (first time only): check the form and send the SMS code. Returns true when the code was sent.
    func sendCode(name: String, mobile: String, username: String, password: String, role: UserRole) async -> Bool {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = mobile.filter(\.isNumber)   // keep only numbers (ignores spaces)
        let chosenUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Simple checks before contacting Firebase
        guard !trimmedName.isEmpty else {
            errorMessage = role == .business ? "Enter your store name." : "Enter your name."
            return false
        }
        guard digits.count == 8 else {
            errorMessage = "Enter your 8-digit Qatar mobile number."
            return false
        }
        // Letters, numbers and _ only, 3 to 20 characters
        let allowed = chosenUsername.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
        guard allowed, (3...20).contains(chosenUsername.count) else {
            errorMessage = "Username: 3 to 20 letters, numbers or _ (no spaces)."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            // Is the username already used by someone else?
            let taken = try await db.collection("users")
                .whereField("username", isEqualTo: chosenUsername)
                .limit(to: 1)
                .getDocuments()
            if !taken.isEmpty {
                errorMessage = "That username is taken. Try another one."
                return false
            }

            let number = "+974" + digits
            // Firebase sends the SMS and gives back an ID we need for step 2
            verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(number, uiDelegate: nil)
            phoneNumber = number
            pendingName = trimmedName
            pendingRole = role
            pendingUsername = chosenUsername
            pendingPassword = password
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Step 2: check the 6-digit code, then set up the username + password and save the profile.
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

        // The SMS code
        let firebaseUser: FirebaseAuth.User
        do {
            // Combine the ID from step 1 with the code the user typed
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID,
                                                                     verificationCode: code)
            firebaseUser = try await Auth.auth().signIn(with: credential).user
        } catch {
            errorMessage = "That code didn't work. Check it and try again."
            return
        }

        // Username + password and the profile
        do {
            try await finishSignUp(firebaseUser)
            pendingPassword = ""
            isSignedIn = true   // RootView now shows the home screen
        } catch {
            try? Auth.auth().signOut()   // don't stay half signed in
            self.verificationID = nil
            // 17007 means the username's hidden email is already used
            if (error as NSError).code == 17007 {
                errorMessage = "That username was just taken. Go back and choose another one."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Saves the new name and photo on the profile (the phone number and username stay the same).
    func updateProfile(name newName: String, photo: UIImage?, removePhoto: Bool) async -> Bool {
        errorMessage = nil
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your name."
            return false
        }
        guard let uid else {
            errorMessage = "Please sign in again."
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            var fields: [String: Any] = ["name": trimmed]
            var newPhotoURL = profile?.photoURL
            if let photo {
                let link = try await PhotoStorage.upload(photo)
                fields["photoURL"] = link
                newPhotoURL = link
            } else if removePhoto {
                fields["photoURL"] = FieldValue.delete()
                newPhotoURL = nil
            }
            try await db.collection("users").document(uid).updateData(fields)
            // Home and Profile show the new details right away
            profile?.name = trimmed
            profile?.photoURL = newPhotoURL
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Signs out and returns to the sign-in screen.
    func signOut() {
        try? Auth.auth().signOut()
        isSignedIn = false
        profile = nil
        verificationID = nil
    }

    /// Adds the username + password to the account and saves the profile.
    /// Returning users keep their profile (older accounts just get a username added).
    private func finishSignUp(_ firebaseUser: FirebaseAuth.User) async throws {
        let uid = firebaseUser.uid
        let ref = db.collection("users").document(uid)
        let snapshot = try await ref.getDocument()

        // Returning user: load the saved profile instead of overwriting it
        if snapshot.exists, var existing = try? snapshot.data(as: ForLess.User.self) {
            if existing.username == nil {
                try await addLogin(to: firebaseUser)
                try await ref.updateData(["username": pendingUsername])
                existing.username = pendingUsername
            }
            existing.id = uid
            profile = existing
            return
        }

        // New user: save name, phone, role and username
        try await addLogin(to: firebaseUser)
        let newUser = ForLess.User(id: nil, name: pendingName, phone: phoneNumber, role: pendingRole,
                                   savedLocations: [], foodPreferences: [], username: pendingUsername)
        try ref.setData(from: newUser)
        var saved = newUser
        saved.id = uid
        profile = saved
    }

    /// Lets this account log in with the username + password too.
    private func addLogin(to firebaseUser: FirebaseAuth.User) async throws {
        let credential = EmailAuthProvider.credential(withEmail: Self.email(for: pendingUsername),
                                                      password: pendingPassword)
        _ = try await firebaseUser.link(with: credential)
    }

    /// Loads the profile of a user who was already signed in when the app opened.
    private func loadProfile(uid: String) async {
        guard let snapshot = try? await db.collection("users").document(uid).getDocument(),
              var user = try? snapshot.data(as: ForLess.User.self) else { return }
        user.id = uid
        profile = user
    }
}
