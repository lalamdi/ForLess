//
//  EditProfileView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Edit profile screen, opened from the Edit button on the Profile tab.
//  The name and the profile photo can be changed (the small + button).
//  The phone number and username are shown but locked.
//  Also has AvatarView: the round picture used here, on Profile and on Home.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    // New photo (optional)
    @State private var photo: UIImage?
    @State private var removedPhoto = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotoMenu = false
    @State private var showLibrary = false
    @State private var showCamera = false

    /// True if there is a picture to show (new or saved) and it was not removed.
    private var hasPhoto: Bool {
        photo != nil || (!removedPhoto && auth.profile?.photoURL != nil)
    }

    /// "+97455990001" becomes "+974 5599 0001".
    private var phoneText: String {
        let phone = auth.profile?.phone ?? ""
        let digits = phone.filter { $0.isNumber }
        if digits.count == 11 && digits.hasPrefix("974") {
            let number = Array(digits.dropFirst(3))
            return "+974 \(String(number[0..<4])) \(String(number[4..<8]))"
        }
        return phone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Round picture with a small + button
                HStack {
                    Spacer()
                    Button {
                        showPhotoMenu = true
                    } label: {
                        AvatarView(
                            name: name,
                            photoURL: removedPhoto ? nil : auth.profile?.photoURL,
                            image: photo,
                            size: 92
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.brand)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white)
                                )
                                .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change profile photo")
                    Spacer()
                }

                LabeledField(label: "Full name") {
                    TextField("Enter your name", text: $name)
                        .textContentType(.name)
                }

                // Locked fields
                if let username = auth.profile?.username {
                    lockedField(label: "Username", value: username)
                }
                lockedField(label: "Mobile number", value: phoneText)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .hideKeyboardOnTap()
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = auth.profile?.name ?? ""
            auth.errorMessage = nil
        }
        // Take a photo / Choose from your photos / Remove photo / Cancel
        .confirmationDialog("Profile photo", isPresented: $showPhotoMenu) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a photo") { showCamera = true }
            }
            Button("Choose from your photos") { showLibrary = true }
            if hasPhoto {
                Button("Remove photo", role: .destructive) {
                    photo = nil
                    removedPhoto = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picture in
                photo = picture
                removedPhoto = false
            }
            .ignoresSafeArea()
        }
        // Load the picture chosen from the library
        .onChange(of: pickedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let picture = UIImage(data: data) {
                    photo = picture
                    removedPhoto = false
                }
            }
        }
        // Save button stays at the bottom of the screen
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    if await auth.updateProfile(name: name, photo: photo, removePhoto: removedPhoto) {
                        dismiss()
                    }
                }
            } label: {
                if auth.isLoading { ProgressView().tint(.white) } else { Text("Save") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.isLoading)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }
    }

    /// A grey box with a lock, for details that can't be edited.
    private func lockedField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ink)
            HStack {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Color(hex: 0xEEF2EF), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Round profile picture

/// The profile photo as a circle. With no photo it shows the first letter on orange.
struct AvatarView: View {
    let name: String
    let photoURL: String?
    var image: UIImage? = nil    // a new photo that is not saved yet
    var size: CGFloat

    /// Saved photos are stored as "data:image/jpeg;base64,..." text, so turn it back into a picture.
    private var savedImage: UIImage? {
        guard let photoURL, photoURL.hasPrefix("data:"),
              let comma = photoURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(photoURL[photoURL.index(after: comma)...])) else {
            return nil
        }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if let shown = image ?? savedImage {
                Image(uiImage: shown)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.brand
                    .overlay(
                        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(Color.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
