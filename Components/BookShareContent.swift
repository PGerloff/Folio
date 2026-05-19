// BookShareContent.swift — builds the share payload for a book recommendation

import SwiftUI
import UIKit

enum BookShareContent {

    // MARK: - Recommendation text

    /// Composes a warm, first-person recommendation string based on the book's
    /// current status and rating. Year is included in parentheses when present.
    @MainActor
    static func text(for book: Book) -> String {
        let byline = book.year != nil
            ? "by \(book.author) (\(book.year!))"
            : "by \(book.author)"

        switch book.status {
        case .finished:
            if let rating = book.rating {
                let stars = String(repeating: "⭐", count: min(max(rating, 1), 5))
                return "Just finished \"\(book.title)\" \(byline) — \(stars). Highly recommend!"
            } else {
                return "Just finished \"\(book.title)\" \(byline) — worth a read."
            }
        case .reading:
            return "Currently reading \"\(book.title)\" \(byline) — looks great so far."
        case .toread, .shopping:
            return "I want to read \"\(book.title)\" \(byline) — heard it's great."
        case .dnf:
            return "I started \"\(book.title)\" \(byline) — let me know what you think."
        }
    }

    // MARK: - Cover image

    /// Returns a UIImage to attach to the share payload.
    ///
    /// Priority:
    ///   1. User photo via `store.loadCoverImage` (cached, cheap).
    ///   2. Renders the placeholder SwiftUI tile via `ImageRenderer` at 300 × 450 pt.
    ///
    /// Must run on the main actor — `ImageRenderer` is @MainActor-isolated.
    @MainActor
    static func coverImage(for book: Book, store: BookStore) async -> UIImage? {
        // Use the real cover photo if available
        if let filename = book.photoFilename,
           let img = store.loadCoverImage(filename) {
            return img
        }

        // Render the coloured placeholder tile
        let width: CGFloat = 300
        let view = CoverView(book, width: width)
            .environment(store)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
