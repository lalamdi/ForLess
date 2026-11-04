
import Foundation

// MARK: - Google Places API Response Models

struct PlacesSearchResponse: Decodable {
    let places: [GooglePlace]
}

struct GooglePlace: Decodable {
    let id: String
    let displayName: PlaceDisplayName?
    let formattedAddress: String?
    let location: PlaceLocation?
    let rating: Double?
    let photos: [PlacePhoto]?
}

struct PlaceDisplayName: Decodable {
    let text: String
}

struct PlaceLocation: Decodable {
    let latitude: Double
    let longitude: Double
}

struct PlacePhoto: Decodable {
    let name: String
}

struct PlacePhotoResponse: Decodable {
    let photoUri: String?
}

// MARK: - Google Places Service

struct GooglePlacesService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // Search for nearby restaurants.
    func searchNearby(
        latitude: Double,
        longitude: Double,
        radius: Double = 3000
    ) async throws -> [GooglePlace] {
        guard let url = URL(
            string: "https://places.googleapis.com/v1/places:searchNearby"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            apiKey,
            forHTTPHeaderField: "X-Goog-Api-Key"
        )

        request.setValue(
            "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.photos",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        let body: [String: Any] = [
            "includedTypes": ["restaurant"],
            "maxResultCount": 10,
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": radius
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "GooglePlacesService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Google Places request failed with status code \(httpResponse.statusCode)."
                ]
            )
        }

        let decodedResponse = try JSONDecoder().decode(
            PlacesSearchResponse.self,
            from: data
        )

        return decodedResponse.places
    }

    // Convert one Google Place into the existing Store model.
    func convertToStore(_ place: GooglePlace) -> Store {
        Store(
            id: nil,
            googlePlaceId: place.id,
            name: place.displayName?.text ?? "Unknown Restaurant",
            type: .restaurant,
            address: place.formattedAddress ?? "",
            latitude: place.location?.latitude ?? 0,
            longitude: place.location?.longitude ?? 0,
            rating: place.rating,
            photoURL: nil,
            ownerId: nil
        )
    }

    // Convert Google results while skipping existing Google Place IDs.
    func convertToStores(
        _ places: [GooglePlace],
        excluding existingStores: [Store] = []
    ) -> [Store] {
        let existingPlaceIDs = Set(
            existingStores.compactMap { $0.googlePlaceId }
        )

        return places
            .filter { !existingPlaceIDs.contains($0.id) }
            .map { convertToStore($0) }
    }

    // Fetch a photo URL for the first available restaurant photo.
    func fetchPhotoURL(for place: GooglePlace) async throws -> URL? {
        guard let photo = place.photos?.first else {
            return nil
        }

        var components = URLComponents(
            string: "https://places.googleapis.com/v1/\(photo.name)/media"
        )

        components?.queryItems = [
            URLQueryItem(name: "maxWidthPx", value: "800"),
            URLQueryItem(name: "skipHttpRedirect", value: "true")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            apiKey,
            forHTTPHeaderField: "X-Goog-Api-Key"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let photoResponse = try JSONDecoder().decode(
            PlacePhotoResponse.self,
            from: data
        )

        guard let photoURLString = photoResponse.photoUri else {
            return nil
        }

        return URL(string: photoURLString)
    }
}
