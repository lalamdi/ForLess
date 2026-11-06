//
//  LocationManager.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Asks the user for location permission and gets their current position.
//  It also turns the coordinates into a place name (e.g. "Education City, Doha")
//
 
import Foundation
import Combine
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var coordinate: CLLocationCoordinate2D?   // user's position once found
    @Published var placeName: String?                     // e.g. "Education City, Doha"
    @Published var isLoading = false
    @Published var errorMessage: String?
 
    private let manager = CLLocationManager()
    private var wantsLocation = false   // true after the user taps "Use my current location"
 
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }
 
    /// Called when the user taps "Use my current location".
    func requestLocation() {
        errorMessage = nil
        wantsLocation = true
 
        switch manager.authorizationStatus {
        case .notDetermined:
            // Shows the iOS "Allow location?" prompt
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLoading = true
            manager.requestLocation()
        default:
            // Denied or restricted
            errorMessage = "Location access is off. Turn it on in Settings > ForLess > Location."
        }
    }
 
    // MARK: - CLLocationManagerDelegate
 
    /// Runs when the user answers the permission prompt.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.status = manager.authorizationStatus
 
            guard self.wantsLocation else { return }
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                self.isLoading = true
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                self.errorMessage = "Location access is off. Turn it on in Settings > ForLess > Location."
            }
        }
    }
 
    /// Runs when the position is found.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.coordinate = location.coordinate
        }
        findPlaceName(for: location)
    }
 
    /// Runs when the position could not be found.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Could not find your location. Please try again."
        }
    }
 
    // MARK: - Place name
 
    /// Turns coordinates into a name like "Education City, Doha".
    private func findPlaceName(for location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let place = placemarks?.first else {
                    self.placeName = "Current location"
                    return
                }
                // Use the area name and the city, for example "Education City, Doha"
                let parts = [place.subLocality, place.locality].compactMap { $0 }
                self.placeName = parts.isEmpty ? "Current location" : parts.joined(separator: ", ")
            }
        }
    }
}
 
