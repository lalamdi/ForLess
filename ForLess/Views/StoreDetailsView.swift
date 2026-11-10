//
//  StoreDetailsView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Business "Store details" screen, opened from the Profile tab.
//  Cards for the store photo and name, the store type, the location
//  (map, address and Change location) and the store phone.
//  Typing a new address moves the map pin to it. Save writes everything
//  to the store in Firestore.
//  The store phone is for customers. The sign-in number does not change.
//

import SwiftUI
import PhotosUI
import MapKit
import FirebaseFirestore

struct StoreDetailsView: View {
    @EnvironmentObject private var auth: AuthManager   // used for the sign-in number
    @Environment(\.dismiss) private var dismiss

    let store: Store
    var onSaved: () -> Void    // lets the Profile tab load the new details

    @State private var name: String
    @State private var address: String
    @State private var type: StoreType
    @State private var phone: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var syncedAddress: String       // the address the map pin matches
    @State private var previewPosition: MapCameraPosition
    @State private var mapNote: String?

    // New store photo (optional)
    @State private var photo: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotoMenu = false
    @State private var showLibrary = false
    @State private var showCamera = false

    @State private var showMapPicker = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var addressFocused: Bool

    init(store: Store, onSaved: @escaping () -> Void) {
        self.store = store
        self.onSaved = onSaved

        // Education City, Doha is used if the store has no position yet
        let hasPosition = store.latitude != 0 || store.longitude != 0
        let lat = hasPosition ? store.latitude : 25.3141
        let lon = hasPosition ? store.longitude : 51.4396

        // Start with the saved values
        _name = State(initialValue: store.name)
        _address = State(initialValue: store.address)
        _type = State(initialValue: store.type)
        _phone = State(initialValue: store.phone ?? "")
        _latitude = State(initialValue: lat)
        _longitude = State(initialValue: lon)
        _syncedAddress = State(initialValue: store.address)
        _previewPosition = State(initialValue: .region(
            MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                               span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
        ))
    }

    // MARK: - Screen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                photoNameCard
                typeCard
                locationCard
                contactCard

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .hideKeyboardOnTap()
        // The error message goes away as soon as a field is changed
        .onChange(of: name + address + phone) { _, _ in
            errorMessage = nil
            mapNote = nil
        }
        .background(Color.appBackground)
        .navigationTitle("Store details")
        .navigationBarTitleDisplayMode(.inline)
        // Save button stays at the bottom of the screen
        .safeAreaInset(edge: .bottom) {
            Button(isSaving ? "Saving..." : "Save changes") {
                Task { await save() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving)
            .opacity(isSaving ? 0.6 : 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }
        .onAppear {
            // No store phone yet: start with the sign-in number
            if phone.isEmpty, let signInPhone = auth.profile?.phone {
                phone = formatPhone(signInPhone)
            }
        }
    }

    // MARK: - Cards

    /// Store photo with a camera button, and the store name.
    private var photoNameCard: some View {
        HStack(spacing: 16) {
            Button {
                showPhotoMenu = true
            } label: {
                avatar
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white)
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: 6, y: 6)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text("Store name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ink)
                TextField("e.g. Za'atar W Zeit", text: $name)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line))
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        // Take a photo / Choose from your photos
        .confirmationDialog("Store photo", isPresented: $showPhotoMenu) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a photo") { showCamera = true }
            }
            Button("Choose from your photos") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picture in photo = picture }
                .ignoresSafeArea()
        }
        // Load the picture chosen from the library
        .onChange(of: pickedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let picture = UIImage(data: data) {
                    photo = picture
                }
            }
        }
    }

    /// The new photo, the saved one, or a shop icon.
    @ViewBuilder
    private var avatar: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else if let urlString = store.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brandLight
            }
        } else {
            Color.brandLight
                .overlay(Image(systemName: "storefront").foregroundStyle(Color.brand))
        }
    }

    /// Restaurant / Grocery switch.
    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("STORE TYPE")

            HStack(spacing: 4) {
                typeButton("Restaurant", icon: "fork.knife", value: .restaurant)
                typeButton("Grocery", icon: "bag", value: .grocery)
            }
            .padding(4)
            .background(Color(hex: 0xEFE7E1), in: RoundedRectangle(cornerRadius: 14))

            // Only when the type was changed
            if type != store.type {
                Text("Your live deals will show under the new type.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func typeButton(_ title: String, icon: String, value: StoreType) -> some View {
        Button {
            type = value
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(type == value ? Color.brandText : Color.muted)
                .background(type == value ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// Small map with the pin, the address and Change location.
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("LOCATION")

            // The map only shows the place (it is not moved by touch here)
            ZStack {
                Map(position: $previewPosition)
                    .allowsHitTesting(false)
                Circle()
                    .fill(Color.brand)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "storefront")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)
                    )
                    .shadow(radius: 3)
                    .offset(y: -17)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            LabeledField(label: "Address") {
                TextField("e.g. Education City, Doha", text: $address)
                    .focused($addressFocused)
                    .submitLabel(.done)
                    .onSubmit { Task { await findAddress() } }
            }
            // When the typing is finished, the pin moves to the address
            .onChange(of: addressFocused) { _, focused in
                if !focused {
                    Task { await findAddress() }
                }
            }

            if let mapNote {
                Text(mapNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
            }

            Button {
                addressFocused = false
                showMapPicker = true
            } label: {
                Label("Change location", systemImage: "location")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $showMapPicker) {
            StoreLocationPickerView(initialAddress: address,
                                    initialLatitude: latitude,
                                    initialLongitude: longitude) { newAddress, lat, lon in
                address = newAddress
                syncedAddress = newAddress
                mapNote = nil
                moveMap(to: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
    }

    /// Store phone (the number customers can see).
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("CONTACT")

            LabeledField(label: "Store phone") {
                TextField("e.g. +974 4412 7788", text: $phone)
                    .keyboardType(.phonePad)
            }

            Text("Shown to customers on your store page. Your sign-in number does not change.")
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.muted)
    }

    // MARK: - Map

    /// Moves the small map and the saved position to a new place.
    private func moveMap(to coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        previewPosition = .region(
            MKCoordinateRegion(center: coordinate,
                               span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
        )
    }

    /// Looks up the typed address and moves the pin to it.
    private func findAddress() async {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != syncedAddress else { return }

        let places = try? await CLGeocoder().geocodeAddressString(text)
        if let coordinate = places?.first?.location?.coordinate {
            moveMap(to: coordinate)
            syncedAddress = text
            mapNote = nil
        } else {
            mapNote = "Couldn't find that address on the map. Use Change location to move the pin."
        }
    }

    // MARK: - Save

    /// Checks the fields, then saves them in the store's document.
    private func save() async {
        errorMessage = nil
        let newName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newName.isEmpty else {
            errorMessage = "Enter the store name."
            return
        }
        guard !newAddress.isEmpty else {
            errorMessage = "Enter the address."
            return
        }
        guard let storeId = store.id else {
            errorMessage = "Could not find the store. Please sign in again."
            return
        }

        isSaving = true
        defer { isSaving = false }

        // If the address was typed and not looked up yet, move the pin first
        await findAddress()

        // An empty phone removes the field
        let phoneValue: Any = newPhone.isEmpty ? FieldValue.delete() : newPhone

        var fields: [String: Any] = [
            "name": newName,
            "address": newAddress,
            "type": type.rawValue,
            "latitude": latitude,
            "longitude": longitude,
            "phone": phoneValue
        ]

        // Upload the new photo (if there is one)
        if let photo {
            do {
                fields["photoURL"] = try await PhotoStorage.upload(photo)
            } catch {
                errorMessage = "Could not upload the photo. Please try again."
                return
            }
        }

        do {
            try await Firestore.firestore().collection("stores").document(storeId)
                .updateData(fields)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Could not save. Please try again."
        }
    }
}
