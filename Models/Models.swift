// Models.swift — Folio data types

import Foundation

// MARK: - Status

enum BookStatus: String, Codable, CaseIterable, Identifiable {
    case shopping  // on the buy list
    case toread    // owned, not started
    case reading   // in progress
    case finished  // read
    case dnf       // paused

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shopping: return "Shop"
        case .toread:   return "To Read"
        case .reading:  return "Reading"
        case .finished: return "Finished"
        case .dnf:      return "Paused"
        }
    }

    /// The four statuses surfaced in pickers (DNF is reachable only via long-press).
    static let pickable: [BookStatus] = [.shopping, .toread, .reading, .finished]
}

// MARK: - Cover color (placeholder tiles)

enum CoverColor: String, Codable, CaseIterable {
    case clay, ochre, rust, olive, cocoa, sand, sage, plum, tea, bone

    static func random() -> CoverColor {
        [.clay, .ochre, .rust, .olive, .cocoa, .sand, .sage, .plum, .tea].randomElement()!
    }

    static func randomAccent() -> CoverColor {
        [.bone, .sand, .cocoa].randomElement()!
    }
}

// MARK: - Note

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
}

// MARK: - Book

struct Book: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var year: Int?
    var status: BookStatus
    var isFavorite: Bool = false
    var rating: Int?
    /// Stored as a short human-readable label ("Mar 2026") because that's how it's displayed.
    var finishedDate: String?
    var addedDate: Date = Date()
    var coverColor: CoverColor = .cocoa
    var accentColor: CoverColor = .sand
    /// Filename of the cover photo within Documents/covers/, or nil for placeholder tile.
    var photoFilename: String?
    var notes: [Note] = []

    var lastNameOfAuthor: String {
        author.split(separator: " ").last.map(String.init) ?? author
    }
}
