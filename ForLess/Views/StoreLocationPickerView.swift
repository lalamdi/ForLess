//
//  StoreLocationPickerView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Map screen opened from Store details ("Change location").
//  The business moves the map until the pin is on the store, or uses the
//  current location. The address follows the pin. "Confirm location" gives
//  the address and the position back to Store details.
//

import SwiftUI
import MapKit

struct StoreLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationManager()

    var onConfirm: (String, Double, Double) -> Void   // address, latitude, longitude

    @State private var center: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition
    @State private var addressText: String
    @State private var skipNextLookup = true   // keeps the saved address until the map is moved

    init(initialAddress: String, initialLatitude: Double, initialLongitude: Double,
         onConfirm: @escaping (String, Double, Double) -> Void) {
        self.onConfirm = onConfirm
        let start = CLLocationCoordinate2D(latitude: initialLatitude, longitude: initialLongitude)
        _center = State(initialValue: start)
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: start, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
        ))
        _addressText = State(initialValue: initialAddress)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                            Image(systemName: "storefront")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.white)
                        )
                        .shadow(radius: 3)
                        .offset(y: -20)
                        .allowsHitTesting(false)
                }

                bottomPanel
            }
            .navigationTitle("Store location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.ink)
                    }
                }
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

    /// Address of the pin, the current location button and Confirm.
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(addressText.isEmpty ? "Move the map to your store" : addressText)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.ink)
                .lineLimit(2)

            Button {
                location.requestLocation()
            } label: {
                Label(location.isLoading ? "Finding your location..." : "Use my current location",
                      systemImage: "location")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandText)
            }

            if let message = location.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
            }

            Button("Confirm location") {
                onConfirm(addressText, center.latitude, center.longitude)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(addressText.isEmpty)
            .opacity(addressText.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground)
    }

    // MARK: - Logic

    /// Turns the pin's position into an address text.
    private func lookUpAddress() {
        if skipNextLookup {
            skipNextLookup = false
            return
        }
        let point = CLLocation(latitude: center.latitude, longitude: center.longitude)
        CLGeocoder().reverseGeocodeLocation(point) { placemarks, _ in
            DispatchQueue.main.async {
                guard let place = placemarks?.first else { return }
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
}
