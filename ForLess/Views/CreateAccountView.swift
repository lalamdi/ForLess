//
//  CreateAccountView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Create account screen (first time only): name, mobile number,
//  username and password. "Continue" sends the SMS code, and the
//  Verify code screen finishes the account.
//

import SwiftUI

struct CreateAccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var role: UserRole
    @State private var name = ""
    @State private var mobile = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showVerify = false           // opens the Verify code screen

    init(startingRole: UserRole) {
        _role = State(initialValue: startingRole)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create your account")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.ink)
                    Text("You only do this once. We'll text a code to check your number.")
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

                LabeledField(label: "Username") {
                    TextField("Choose a username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                LabeledField(label: "Password") {
                    PasswordField(placeholder: "At least 6 characters", text: $password)
                }

                // Error from AuthManager (e.g. username taken)
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        // Button stays at the bottom of the screen
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    Task {
                        // Go to the Verify screen only if the SMS was sent
                        if await auth.sendCode(name: name, mobile: mobile, username: username,
                                               password: password, role: role) {
                            showVerify = true
                        }
                    }
                } label: {
                    if auth.isLoading { ProgressView().tint(.white) } else { Text("Continue") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(auth.isLoading)

                Button {
                    dismiss()
                } label: {
                    Text("Already have an account? ")
                        .foregroundStyle(Color.muted)
                    + Text("Log in")
                        .foregroundStyle(Color.brandText)
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.white)
        }
        .background(Color.white)
        .hideKeyboardOnTap()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showVerify) { VerifyCodeView() }
        .onChange(of: role) { auth.errorMessage = nil }   // clear old errors when switching tabs
        .onAppear { auth.errorMessage = nil }
    }
}
