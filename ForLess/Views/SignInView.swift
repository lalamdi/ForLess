//
//   Business switch..swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Log in screen (email + password, Customer or Business)
//  and the Check your email screen (first time only).
//  New users make their account on the Create account screen.
//

import SwiftUI

// MARK: - Log in screen (first screen)

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var role: UserRole = .customer   // Customer or Business tab
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Logo and app name
                    HStack(spacing: 10) {
                        AppIconView(size: 48)
                        Text("For Less")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(Color.brandDark)
                    }

                    // Heading changes for customers and businesses
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(Color.ink)
                        Text(role == .customer
                             ? "Log in to grab discounted meals and groceries near you before they go to waste."
                             : "Log in to post surplus food and manage pickup orders.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.muted)
                    }

                    RolePicker(role: $role)

                    LabeledField(label: "Email") {
                        TextField("Enter your email", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    LabeledField(label: "Password") {
                        PasswordField(placeholder: "Enter your password", text: $password)
                    }

                    // Error from AuthManager (e.g. wrong password)
                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            // Buttons stay at the bottom of the screen
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        Task { await auth.logIn(username: username, password: password, role: role) }
                    } label: {
                        if auth.isLoading { ProgressView().tint(.white) } else { Text("Log in") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(auth.isLoading)

                    // First time users make an account with their email
                    NavigationLink {
                        CreateAccountView(startingRole: role)
                    } label: {
                        Text("New here? Create an account")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.brandText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brand, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.white)
            }
            .background(Color.white)
            .hideKeyboardOnTap()
            .onChange(of: role) { auth.errorMessage = nil }   // clear old errors when switching tabs
            .onAppear { auth.errorMessage = nil }
        }
    }
}

// MARK: - Password box

/// Password field with an eye button to show or hide the password.
struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isShown = false

    var body: some View {
        HStack {
            Group {
                if isShown {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isShown.toggle()
            } label: {
                Image(systemName: isShown ? "eye.slash" : "eye")
                    .foregroundStyle(Color.muted)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Customer / Business switch

/// Two-tab switch to choose a customer or business account.
struct RolePicker: View {
    @Binding var role: UserRole

    var body: some View {
        HStack(spacing: 4) {
            tab("Customer", icon: "person", value: .customer)
            tab("Business", icon: "storefront", value: .business)
        }
        .padding(4)
        .background(Color(hex: 0xEFE7E1), in: RoundedRectangle(cornerRadius: 14))
    }

    /// One tab; the selected tab gets a white background.
    private func tab(_ title: String, icon: String, value: UserRole) -> some View {
        let selected = role == value
        return Button { role = value } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(selected ? Color.ink : Color.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Check your email screen

struct CheckEmailView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
                .foregroundStyle(Color.brand)

            VStack(alignment: .leading, spacing: 8) {
                Text("Check your email")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text("We sent a link to \(auth.pendingEmail). Tap it to confirm your email, then come back here. If you can't see it, check your spam folder.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            }
            if let info = auth.infoMessage {
                Text(info)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandText)
            }

            Button("Send the email again") {
                Task { await auth.resendVerification() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.ink)

            // Deletes the unverified account and goes back
            Button("Use a different email") {
                Task {
                    await auth.cancelSignUp()
                    dismiss()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.ink)

            Spacer()

            Button {
                Task { await auth.checkVerified() }
            } label: {
                if auth.isLoading { ProgressView().tint(.white) } else { Text("I've verified my email") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.isLoading)
        }
        .padding(24)
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            auth.errorMessage = nil
            auth.infoMessage = nil
        }
    }
}
