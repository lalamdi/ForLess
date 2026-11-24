//
//  AuthManager.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Handles sign-in with Firebase Authentication (email + password):
//  - signUp            - creates the account and emails a verification link
//  - checkVerified     - after the user taps the link, lets them in
//  - resendVerification, cancelSignUp - for the "Check your email" screen
//  - logIn             - email (or username for older accounts) + password
//  Older accounts that were made with a username still work: the username is
//  turned into a hidden email (name@forless.app). The profile (name, email,
//  role) is stored in the Firestore "users" collection.
//

import Foundation
import UIKit
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthManager: ObservableObject {
    @Published var isSignedIn = false            // true once the user is signed in and verified
    @Published var profile: ForLess.User?        // our User struct (ForLess.User avoids a clash with Firebase's User)
    @Published var isLoading = false             // shows a spinner on the buttons
    @Published var errorMessage: String?         // shown in red on the sign-in screens
    @Published var infoMessage: String?          // green note, e.g. "Email sent again"

    private(set) var pendingEmail = ""           // the email we sent the link to
    private var pendingProfile: ForLess.User?    // profile waiting for the email to be verified
    private let db = Firestore.firestore()

    init() {
        // If the user signed in before (and verified), skip the sign-in screen
        if let current = Auth.auth().currentUser, Self.isVerified(current) {
            isSignedIn = true
            Task { await loadProfile(uid: current.uid) }
        }
    }

    /// Older accounts (made with a username) count as verified; new accounts need the email link.
    private static func isVerified(_ user: FirebaseAuth.User) -> Bool {
        user.isEmailVerified || (user.email ?? "").hasSuffix("@forless.app")
    }

    /// The signed-in user's Firebase ID (used as customerId on orders).
    var uid: String? { Auth.auth().currentUser?.uid }

    /// Hidden email Firebase uses for an old username, e.g. test1 becomes test1@forless.app
    private static func email(for loginName: String) -> String {
        loginName.contains("@") ? loginName : loginName + "@forless.app"
    }

    /// Friendly text for the common Firebase errors.
    private func message(for error: Error) -> String {
        switch (error as NSError).code {
        case 17007: return "That email already has an account. Try logging in."
        case 17008: return "That email doesn't look right."
        case 17026: return "Password must be at least 6 characters."
        case 17004, 17009, 17011: return "Wrong email or password."
        case 17010: return "Too many tries. Wait a minute and try again."
        default: return error.localizedDescription
        }
    }

    /// Log in with email + password (older accounts can still use their username).
    func logIn(username: String, password: String, role: UserRole) async {
        errorMessage = nil
        infoMessage = nil
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: Self.email(for: name), password: password)

            // New accounts have to verify their email first
            if !Self.isVerified(result.user) {
                try? await result.user.sendEmailVerification()
                try? Auth.auth().signOut()
                errorMessage = "Please verify your email first. We sent you a new link."
                return
            }

            let snapshot = try await db.collection("users").document(result.user.uid).getDocument()
            guard var user = try? snapshot.data(as: ForLess.User.self) else {
                // The sign-up never finished saving the profile: remove this half-made account
                // so the same email can be used to create it again
                try? await result.user.delete()
                try? Auth.auth().signOut()
                errorMessage = "This account wasn't set up properly, so we removed it. Please create it again."
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
            errorMessage = message(for: error)
        }
    }

    /// Step 1 (first time only): create the account and email the verification link.
    /// Returns true when the email was sent.
    func signUp(name: String, email: String, password: String, role: UserRole) async -> Bool {
        errorMessage = nil
        infoMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty else {
            errorMessage = role == .business ? "Enter your store name." : "Enter your name."
            return false
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Enter a valid email."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            try await result.user.sendEmailVerification()

            // Save the profile now; the user is let in after they verify
            let newUser = ForLess.User(id: nil, name: trimmedName, phone: "", role: role,
                                       savedLocations: [], foodPreferences: [], username: nil,
                                       photoURL: nil, email: trimmedEmail)
            // "await" so a failed save shows an error instead of being missed
            try await db.collection("users").document(result.user.uid)
                .setData(try Firestore.Encoder().encode(newUser))
            var saved = newUser
            saved.id = result.user.uid
            pendingProfile = saved
            pendingEmail = trimmedEmail
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    /// Step 2: the user tapped the link in the email. Checks it and lets them in.
    func checkVerified() async {
        errorMessage = nil
        infoMessage = nil
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please go back and create your account again."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            try await user.reload()   // gets the newest "verified" status from Firebase
            guard user.isEmailVerified else {
                errorMessage = "Not verified yet. Open the link in the email first (check spam too)."
                return
            }
            profile = pendingProfile
            pendingProfile = nil
            isSignedIn = true   // RootView now shows the home screen
        } catch {
            errorMessage = message(for: error)
        }
    }

    /// Sends the verification email again.
    func resendVerification() async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await Auth.auth().currentUser?.sendEmailVerification()
            infoMessage = "We sent the email again."
        } catch {
            errorMessage = message(for: error)
        }
    }

    /// Wrong email? Deletes the unverified account so the user can start again.
    func cancelSignUp() async {
        errorMessage = nil
        infoMessage = nil
        if let user = Auth.auth().currentUser {
            try? await db.collection("users").document(user.uid).delete()
            try? await user.delete()
        }
        try? Auth.auth().signOut()
        pendingProfile = nil
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
    }

    /// Loads the profile of a user who was already signed in when the app opened.
    private func loadProfile(uid: String) async {
        guard let snapshot = try? await db.collection("users").document(uid).getDocument(),
              var user = try? snapshot.data(as: ForLess.User.self) else { return }
        user.id = uid
        profile = user
    }
}
