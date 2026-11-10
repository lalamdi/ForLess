//
//   Business switch..swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Sign-in screen (name + mobile number, Customer or Business)
//  and the Verify code screen (6-digit SMS code).
//

import SwiftUI

// MARK: - Sign in screen

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var role: UserRole = .customer   // Customer or Business tab
    @State private var name = ""
    @State private var mobile = ""
    @State private var showVerify = false           // opens the Verify code screen

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
                        Text(role == .customer ? "Good food, less waste" : "Sell surplus, waste less")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(Color.ink)
                        Text(role == .customer
                             ? "Sign in to grab discounted meals and groceries near you before they go to waste."
                             : "For restaurants and grocery stores. Post surplus food and manage pickup orders.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.muted)
                    }

                    RolePicker(role: $role)

                    // Name field (store name for businesses)
                    LabeledField(label: role == .customer ? "Full name" : "Store name") {
                        TextField(role == .customer ? "Enter your name" : "e.g. Za'atar W Zeit", text: $name)
                            .textContentType(role == .customer ? UITextContentType.name : .organizationName)
                    }

                    // Mobile number field with the fixed Qatar code
                    LabeledField(label: role == .customer ? "Mobile number" : "Business mobile number") {
                        HStack(spacing: 12) {
                            Text("+974").font(.system(size: 15, weight: .semibold))
                            Rectangle().fill(Color.line).frame(width: 1, height: 20)
                            TextField("5XXX XXXX", text: $mobile)
                                .keyboardType(.numberPad)
                                .textContentType(.telephoneNumber)
                        }
                    }

                    Text("We'll send a code by SMS to verify your number.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.muted)

                    // Error from AuthManager (e.g. wrong number format)
                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            // Button stays at the bottom of the screen
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        Task {
                            // Go to the Verify screen only if the SMS was sent
                            if await auth.sendCode(name: name, mobile: mobile, role: role) {
                                showVerify = true
                            }
                        }
                    } label: {
                        if auth.isLoading { ProgressView().tint(.white) } else { Text("Send code") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(auth.isLoading)

                    Text("By continuing you agree to our Terms & Privacy Policy.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.white)
            }
            .background(Color.white)
            .hideKeyboardOnTap()
            .navigationDestination(isPresented: $showVerify) { VerifyCodeView() }
            .onChange(of: role) { auth.errorMessage = nil }   // clear old errors when switching tabs
        }
    }
}

// MARK: - Customer / Business switch

/// Two-tab switch to choose a customer or business account.
private struct RolePicker: View {
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

// MARK: - Verify code screen

struct VerifyCodeView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var focused: Bool   // keeps the keyboard open for typing the code

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verify your number")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text("Enter the 6-digit code we sent to \(auth.phoneNumber)")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)
            }

            // Six boxes that show the typed digits
            ZStack {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let digit = index < code.count ? String(Array(code)[index]) : ""
                        let isCurrent = index == code.count && focused   // the next box to fill
                        Text(digit)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(digit.isEmpty ? Color.white : Color.brandLight,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(isCurrent ? Color.brand : Color.line, lineWidth: isCurrent ? 2 : 1))
                    }
                }
                // Invisible field on top of the boxes that receives the typing
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)   // lets iOS auto-fill the SMS code
                    .focused($focused)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .frame(height: 60)
                    .opacity(0.02)
                    .onChange(of: code) { _, newValue in
                        // Keep only numbers, maximum 6 digits
                        let cleaned = String(newValue.filter(\.isNumber).prefix(6))
                        if cleaned != newValue { code = cleaned }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            }

            // Goes back to the sign-in screen
            Button("Change mobile number") {
                auth.errorMessage = nil
                dismiss()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.ink)

            Spacer()

            Button {
                Task { await auth.verify(code: code) }
            } label: {
                if auth.isLoading { ProgressView().tint(.white) } else { Text("Verify & continue") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(code.count < 6 || auth.isLoading)   // only active when 6 digits are typed
            .opacity(code.count < 6 ? 0.5 : 1)
        }
        .padding(24)
        .background(Color.white)
        .onAppear {
            focused = true
            auth.errorMessage = nil
        }
    }
}
