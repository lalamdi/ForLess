//
//  LocationPopupView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Customer "Where should we find deals?" pop-up.
//  The user can use their current location or pick a saved address,
//  then taps "Confirm location".
//  The screen only reports the choice through onConfirm.
//  The saved addresses are passed in, so this view does not read Firestore itself.
//
 

import SwiftUI
 
/// One place the user can choose (a saved address or the current location).
struct LocationOption: Identifiable, Equatable {
    let id: String
    let title: String      // e.g. "Home"
    let address: String    // e.g. "Education City, Doha"
    let icon: String       // SF Symbol name
}
 
struct LocationPopupView: View {
    @StateObject private var location = LocationManager()
    @State private var selectedId: String?          // which row is chosen
    @State private var currentOption: LocationOption?   // filled once the location is found
 
    var savedPlaces: [LocationOption]
    var onConfirm: (LocationOption) -> Void
    var onAddAddress: () -> Void
 
    /// The row the user picked (current location or one of the saved places).
    private var selectedOption: LocationOption? {
        if selectedId == currentOption?.id { return currentOption }
        return savedPlaces.first { $0.id == selectedId }
    }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where should we find deals?")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.ink)
                Text("Turn on location so we can show deals near you, or pick a saved address.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
            }
 
            currentLocationRow
 
            if let message = location.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
            }
 
            if !savedPlaces.isEmpty {
                Text("SAVED LOCATIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.muted)
 
                VStack(spacing: 10) {
                    ForEach(savedPlaces) { place in
                        placeRow(place)
                    }
                }
            }
 
            Button {
                onAddAddress()
            } label: {
                Label("Add new address", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandText)
            }
 
            Button("Confirm location") {
                if let option = selectedOption {
                    onConfirm(option)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedOption == nil)
            .opacity(selectedOption == nil ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        // Fill the whole sheet, content at the top
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        // When the place name is found, add it as a row and select it
        .onChange(of: location.placeName) { _, name in
            guard let name else { return }
            let option = LocationOption(id: "current", title: "Current location", address: name, icon: "location.fill")
            currentOption = option
            selectedId = option.id
        }
        // Start with the first saved address selected
        .onAppear {
            if selectedId == nil {
                selectedId = savedPlaces.first?.id
            }
        }
    }
 
    // MARK: - Pieces of the screen
 
    /// Orange "Use my current location" box.
    private var currentLocationRow: some View {
        Button {
            location.requestLocation()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use my current location")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandDark)
                    // Shows the found place, "Finding..." or the default text
                    Text(currentLocationSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.brandText)
                }
                Spacer()
                if location.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandText)
                }
            }
            .padding(12)
            .background(Color.brandLight, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
 
    private var currentLocationSubtitle: String {
        if location.isLoading { return "Finding your location..." }
        if let name = location.placeName { return name }
        return "Turn on location access"
    }
 
    /// One saved address with a radio circle on the right.
    private func placeRow(_ place: LocationOption) -> some View {
        let isSelected = selectedId == place.id
        return Button {
            selectedId = place.id
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: place.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.ink)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ink)
                    Text(place.address)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.brand : Color.line)
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.brand : Color.line, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
 
// Preview with two example addresses (only used in Xcode's canvas)
#Preview {
    LocationPopupView(
        savedPlaces: [
            LocationOption(id: "home", title: "Home", address: "Education City, Doha", icon: "house"),
            LocationOption(id: "work", title: "Work", address: "West Bay, Doha", icon: "briefcase")
        ],
        onConfirm: { _ in },
        onAddAddress: {}
    )
}
