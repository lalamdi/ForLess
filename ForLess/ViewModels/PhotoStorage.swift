//
//  PhotoStorage.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Turns a deal photo into a small text link that is saved in the deal's photoURL.
//  No file upload is needed, so Firebase Storage is not used.
//  The picture is made small first, because a Firestore document can only hold 1 MB.
//

import UIKit

enum PhotoStorage {

    /// Returns the picture as a "data:" link to save in the deal's photoURL.
    static func upload(_ image: UIImage) async throws -> String {
        let small = resized(image, maxWidth: 500)

        // Lower the quality until the picture is small enough
        var quality: CGFloat = 0.6
        while quality >= 0.2 {
            if let jpeg = small.jpegData(compressionQuality: quality), jpeg.count <= 150_000 {
                return "data:image/jpeg;base64," + jpeg.base64EncodedString()
            }
            quality -= 0.1
        }
        throw URLError(.dataLengthExceedsMaximum)
    }

    /// Makes the picture at most maxWidth wide (it is never made bigger).
    private static func resized(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
