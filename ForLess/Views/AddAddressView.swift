//
//  AddAddressView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//



//  Customer "Add new address" screen 
//  Pick a spot on the map, choose Home, Work or Other, and save it.
//  It is also used to edit or delete a saved address (editing is not nil).
//
 
import SwiftUI
import MapKit
import FirebaseFirestore
 
struct AddAddressView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationManager()
    @FocusState private var addressFocused: Bool
 
    // Education City, Doha is where the map starts
    @State private var center = CLLocationCoordinate2D(latitude: 25.3141, longitude: 51.4396)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 25.3141, longitude: 51.4396),
                           span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
    )
 
    @State private var label = "Home"        // Home, Work or Other
    @State private var customName = ""       // name for "Other", e.g. "Gym"
    @State private var addressText = ""
    @State private var floorText = ""
    @State private var skipNextLookup = false   // stops the map from replacing the current-location address
    @State private var errorMessage: String?
    @State private var isSaving = false
 
    @State private var showDeleteAlert = false
 
    private let labels = ["Home", "Work", "Other"]
    let editing: SavedLocation?   // nil = new address, otherwise the address being edited
 
    init(editing: SavedLocation? = nil) {
        self.editing = editing
        // When editing, start with the saved values
        if let place = editing {
            let start = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let isStandard = place.label == "Home" || place.label == "Work"
            _center = State(initialValue: start)
            _cameraPosition = State(initialValue: .region(
                MKCoordinateRegion(center: start, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
            ))
            _label = State(initialValue: isStandard ? place.label : "Other")
            _customName = State(initialValue: (isStandard || place.label == "Other") ? "" : place.label)
            _addressText = State(initialValue: place.address)
            _skipNextLookup = State(initialValue: true)   // keep the saved address text
        }
    }
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mapBox
 
                    Text("Save as")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    labelChips
 
                    // Only for "Other": the customer types a name
                    if label == "Other" {
                        LabeledField(label: "Name") {
                            TextField("e.g. Gym, Mom's house", text: $customName)
                        }
                    }
 
                    LabeledField(label: "Address") {
                        TextField("e.g. Building 12, Education City, Doha", text: $addressText)
                            .focused($addressFocused)
                    }
 
                    LabeledField(label: "Floor / apartment (optional)") {
                        TextField("e.g. 2nd floor, Apt 4", text: $floorText)
                    }
 
                    // Moves the map to where the phone is
                    Button {
                        location.requestLocation()
                    } label: {
                        Label(location.isLoading ? "Finding your location..." : "Use my current location instead",
                              systemImage: "location")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandText)
                    }
 
                    // Only when editing a saved address
                    if editing != nil {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete address", systemImage: "trash")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
 
                    if let message = location.errorMessage ?? errorMessage {
                        Text(message)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .navigationTitle(editing == nil ? "Add new address" : "Edit address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.ink)
                    }
                }
            }
            // Save button stays at the bottom of the screen
            .safeAreaInset(edge: .bottom) {
                Button(isSaving ? "Saving..." : (editing == nil ? "Save address" : "Save changes")) {
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
                if editing == nil {
                    label = firstFreeLabel()
                    lookUpAddress()
                } else {
                    // The map may move once when it opens, so do not replace the saved text
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        skipNextLookup = false
                    }
                }
            }
            .alert("Delete this address?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { Task { await deleteAddress() } }
            } message: {
                Text("It will be removed from your saved locations.")
            }
            // Current location found: move the map there
            .onChange(of: location.coordinate?.latitude) { _, _ in
                guard let coordinate = location.coordinate else { return }
                skipNextLookup = true
                center = coordinate
                cameraPosition = .region(
                    MKCoordinateRegion(center: coordinate,
                                       span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
                )
                // If the map does not move, the skip must not stay on
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    skipNextLookup = false
                }
            }
            // Place name found: fill in the address
            .onChange(of: location.placeName) { _, name in
                if let name {
                    addressText = name
                }
            }
        }
    }
 
    // MARK: - Pieces of the screen
 
    /// Map with a pin in the middle. The address follows where the map stops.
    private var mapBox: some View {
        ZStack {
            Map(position: $cameraPosition)
                .onMapCameraChange(frequency: .onEnd) { context in
                    center = context.region.center
                    lookUpAddress()
                }
 
            // Pin fixed in the middle of the map
            Circle()
                .fill(Color.brand)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "mappin")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                )
                .shadow(radius: 3)
                .offset(y: -20)
                .allowsHitTesting(false)
 
            VStack {
                Spacer()
                Text("Move the map to your building")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandLight, in: Capsule())
                    .padding(.bottom, 10)
            }
            .allowsHitTesting(false)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
 
    /// Home / Work / Other chips. The chosen one is dark.
    private var labelChips: some View {
        HStack(spacing: 8) {
            ForEach(labels, id: \.self) { option in
                Button {
                    label = option
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .foregroundStyle(label == option ? Color.white : Color.ink)
                        .background(label == option ? Color.ink : Color.white, in: Capsule())
                        .overlay(Capsule().stroke(label == option ? Color.clear : Color.line))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
 
    // MARK: - Logic
 
    /// Starts on Home, or Work if Home is already saved, or Other if both are.
    private func firstFreeLabel() -> String {
        let saved = (auth.profile?.savedLocations ?? []).map { $0.label }
        if !saved.contains("Home") { return "Home" }
        if !saved.contains("Work") { return "Work" }
        return "Other"
    }
 
    /// Turns the map's middle point into an address text (unless the customer is typing).
    private func lookUpAddress() {
        if skipNextLookup {
            skipNextLookup = false
            return
        }
        let point = CLLocation(latitude: center.latitude, longitude: center.longitude)
        CLGeocoder().reverseGeocodeLocation(point) { placemarks, _ in
            DispatchQueue.main.async {
                guard !addressFocused, let place = placemarks?.first else { return }
                // Name, area and city, without repeating the same word
                var parts: [String] = []
                for part in [place.name, place.subLocality, place.locality] {
                    if let part, !parts.contains(part) {
                        parts.append(part)
                    }
                }
                if !parts.isEmpty {
                    addressText = parts.joined(separator: ", ")
                }
            }
        }
    }
 
    /// Saves the address in the user's savedLocations in Firestore.
    private func save() async {
        errorMessage = nil
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter the address."
            return
        }
 
        // "Other" uses the name the customer typed
        var savedLabel = label
        if label == "Other" {
            let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            savedLabel = name.isEmpty ? "Other" : name
        }
 
        guard let uid = auth.uid else {
            errorMessage = "You are signed out. Please sign in again."
            return
        }
 
        // The floor / apartment is added to the end of the address
        let floor = floorText.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullAddress = floor.isEmpty ? trimmed : "\(trimmed), \(floor)"
 
        let newPlace = SavedLocation(label: savedLabel, address: fullAddress,
                                     latitude: center.latitude, longitude: center.longitude)
 
        var places = auth.profile?.savedLocations ?? []
        if let original = editing, let index = places.firstIndex(of: original) {
            // Editing: the changed address takes the old one's place
            places.remove(at: index)
            places.removeAll { $0.label == savedLabel }
            places.insert(newPlace, at: min(index, places.count))
        } else {
            // New: a place with the same name is replaced, so there are no duplicates
            places.removeAll { $0.label == savedLabel }
            places.append(newPlace)
        }
 
        isSaving = true
        defer { isSaving = false }
        if await writePlaces(places, uid: uid) {
            dismiss()
        }
    }
 
    /// Removes the address being edited.
    private func deleteAddress() async {
        guard let original = editing, let uid = auth.uid else { return }
        var places = auth.profile?.savedLocations ?? []
        places.removeAll { $0 == original }
        isSaving = true
        defer { isSaving = false }
        if await writePlaces(places, uid: uid) {
            dismiss()
        }
    }
 
    /// Saves the list in Firestore. Returns false if it failed.
    private func writePlaces(_ places: [SavedLocation], uid: String) async -> Bool {
        do {
            let encoder = Firestore.Encoder()
            let encoded = try places.map { try encoder.encode($0) }
            try await Firestore.firestore().collection("users").document(uid)
                .updateData(["savedLocations": encoded])
            auth.profile?.savedLocations = places   // the other screens show it straight away
            return true
        } catch {
            errorMessage = "Could not save the address. Please try again."
            return false
        }
    }
}
