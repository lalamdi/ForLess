//
//  CachedAsyncImage.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Works like AsyncImage, but remembers the pictures it already loaded.
//  AsyncImage forgets them, so switching between Restaurants and Groceries
//  made every photo load again. This one shows them straight away.
//

import SwiftUI

/// Pictures that were already loaded (kept while the app is open).
enum ImageCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var picture: UIImage?

    init(
        url: URL,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        // Already loaded before? Show it right away.
        _picture = State(initialValue: ImageCache.shared.object(forKey: url.absoluteString as NSString))
    }

    var body: some View {
        Group {
            if let picture {
                content(Image(uiImage: picture))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        let key = url.absoluteString as NSString
        if let cached = ImageCache.shared.object(forKey: key) {
            picture = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let loaded = UIImage(data: data) else { return }
        ImageCache.shared.setObject(loaded, forKey: key)
        picture = loaded
    }
}
