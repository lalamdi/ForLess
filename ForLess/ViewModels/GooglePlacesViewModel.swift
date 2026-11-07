
import Foundation
import Combine

@MainActor
final class GooglePlacesViewModel: ObservableObject {

    @Published var restaurants: [Store] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiKey: String?

    // Education City, Doha
    private let latitude = 25.3141
    private let longitude = 51.4396

    init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    func loadRestaurants(existingStores: [Store] = []) async {
        guard let apiKey = apiKey,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Google Places API key has not been configured yet."
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let service = GooglePlacesService(apiKey: apiKey)

            let places = try await service.searchNearby(
                latitude: latitude,
                longitude: longitude
            )

            var loadedStores = service.convertToStores(
                places,
                excluding: existingStores
            )

            // Retrieve a photo for each restaurant when available.
            for index in loadedStores.indices {
                guard let place = places.first(where: {
                    $0.id == loadedStores[index].googlePlaceId
                }) else {
                    continue
                }

                do {
                    let photoURL = try await service.fetchPhotoURL(for: place)
                    loadedStores[index].photoURL = photoURL?.absoluteString
                } catch {
                    // Keep the restaurant even if its photo cannot be loaded.
                    loadedStores[index].photoURL = nil
                }
            }

            restaurants = loadedStores

        } catch {
            errorMessage = "Could not load restaurants: \(error.localizedDescription)"
        }
    }
}

