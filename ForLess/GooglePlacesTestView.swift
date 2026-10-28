
import SwiftUI

struct GooglePlacesTestView: View {
    @StateObject private var viewModel = GooglePlacesViewModel(
        apiKey: Bundle.main.object(
            forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY"
        ) as? String
    )

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading nearby restaurants...")
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)

                        Text(errorMessage)
                            .multilineTextAlignment(.center)

                        Button("Try Again") {
                            Task {
                                await viewModel.loadRestaurants()
                            }
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(
                            viewModel.restaurants,
                            id: \.googlePlaceId
                        ) { restaurant in
                            HStack(alignment: .top, spacing: 12) {
                                restaurantPhoto(restaurant.photoURL)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(restaurant.name)
                                        .font(.headline)

                                    if !restaurant.address.isEmpty {
                                        Text(restaurant.address)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let rating = restaurant.rating {
                                        Label(
                                            String(format: "%.1f", rating),
                                            systemImage: "star.fill"
                                        )
                                        .font(.subheadline)
                                    }

                                    Text(
                                        "Place ID: \(restaurant.googlePlaceId ?? "Unavailable")"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Nearby Restaurants")
            .toolbar {
                Button("Refresh") {
                    Task {
                        await viewModel.loadRestaurants()
                    }
                }
            }
            .task {
                if viewModel.restaurants.isEmpty &&
                    viewModel.errorMessage == nil {
                    await viewModel.loadRestaurants()
                }
            }
        }
    }

    @ViewBuilder
    private func restaurantPhoto(_ photoURL: String?) -> some View {
        if let photoURL,
           let url = URL(string: photoURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "fork.knife")
                .font(.title2)
                .frame(width: 90, height: 90)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    GooglePlacesTestView()
}
