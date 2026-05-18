// BookStore.swift — observable store with file-based persistence
// Books + favorite authors persist as JSON in Documents/folio.json.
// Cover photos live as JPEGs in Documents/covers/<filename>.

import Foundation
import SwiftUI
import UIKit
import Observation

@Observable
final class BookStore {
    var books: [Book] = []
    var favoriteAuthors: Set<String> = []

    private let storeURL: URL
    private let coversDir: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storeURL = docs.appendingPathComponent("folio.json")
        self.coversDir = docs.appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        load()
        if books.isEmpty { seed() }
    }

    // MARK: - Query

    func book(_ id: UUID) -> Book? { books.first { $0.id == id } }

    func books(status: BookStatus) -> [Book] { books.filter { $0.status == status } }

    /// Owned books = everything that isn't on the shopping list.
    var owned: [Book] { books.filter { $0.status != .shopping } }

    var favorites: [Book] { books.filter { $0.isFavorite } }

    // MARK: - Mutate

    @discardableResult
    func addBook(title: String,
                 author: String = "Unknown",
                 year: Int? = nil,
                 status: BookStatus = .shopping,
                 photoData: Data? = nil) -> UUID {
        var book = Book(
            title: title.isEmpty ? "Untitled" : title,
            author: author.isEmpty ? "Unknown" : author,
            year: year,
            status: status,
            coverColor: .random(),
            accentColor: .randomAccent()
        )
        if let data = photoData {
            book.photoFilename = writePhoto(data: data, for: book.id)
        }
        books.insert(book, at: 0)
        save()
        return book.id
    }

    func update(_ id: UUID, _ transform: (inout Book) -> Void) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        transform(&books[idx])
        save()
    }

    func remove(_ id: UUID) {
        if let book = book(id), let name = book.photoFilename {
            try? FileManager.default.removeItem(at: coversDir.appendingPathComponent(name))
        }
        books.removeAll { $0.id == id }
        save()
    }

    func setStatus(_ id: UUID, _ status: BookStatus) {
        update(id) { book in
            book.status = status
            if status == .finished, book.finishedDate == nil {
                book.finishedDate = Self.finishedFormatter.string(from: Date())
            }
        }
    }

    func toggleFavorite(_ id: UUID) {
        update(id) { $0.isFavorite.toggle() }
    }

    func setRating(_ id: UUID, _ rating: Int?) {
        update(id) { $0.rating = rating }
    }

    func setPhoto(_ id: UUID, data: Data?) {
        update(id) { book in
            // Remove old file if replacing/clearing
            if let old = book.photoFilename {
                try? FileManager.default.removeItem(at: coversDir.appendingPathComponent(old))
                book.photoFilename = nil
            }
            if let data {
                book.photoFilename = writePhoto(data: data, for: book.id)
            }
        }
    }

    func toggleFavoriteAuthor(_ name: String) {
        if favoriteAuthors.contains(name) {
            favoriteAuthors.remove(name)
        } else {
            favoriteAuthors.insert(name)
        }
        save()
    }

    func addNote(_ bookId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(bookId) { $0.notes.insert(Note(text: trimmed), at: 0) }
    }

    func removeNote(_ bookId: UUID, noteId: UUID) {
        update(bookId) { $0.notes.removeAll { $0.id == noteId } }
    }

    // MARK: - Photo files

    /// Returns a `UIImage` loaded from the covers directory, or nil.
    func loadCoverImage(_ filename: String) -> UIImage? {
        let url = coversDir.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    private func writePhoto(data: Data, for bookId: UUID) -> String? {
        // Re-encode as JPEG @ 0.85 to keep file size sane.
        let normalized: Data = {
            if let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.85) {
                return jpeg
            }
            return data
        }()
        let filename = "\(bookId.uuidString).jpg"
        let url = coversDir.appendingPathComponent(filename)
        do {
            try normalized.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var books: [Book]
        var favoriteAuthors: [String]
    }

    private func save() {
        let payload = Persisted(books: books, favoriteAuthors: Array(favoriteAuthors))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(Persisted.self, from: data) {
            self.books = payload.books
            self.favoriteAuthors = Set(payload.favoriteAuthors)
        }
    }

    func resetToSeed() {
        // Clear photo files for current books
        for book in books {
            if let name = book.photoFilename {
                try? FileManager.default.removeItem(at: coversDir.appendingPathComponent(name))
            }
        }
        books.removeAll()
        favoriteAuthors.removeAll()
        seed()
    }

    // MARK: - Seed

    private func seed() {
        favoriteAuthors = ["Virginia Woolf", "Toni Morrison"]
        books = [
            .init(title: "Piranesi",                author: "Susanna Clarke",        year: 2020, status: .reading,  isFavorite: true,  coverColor: .cocoa, accentColor: .sand),
            .init(title: "Orlando",                 author: "Virginia Woolf",        year: 1928, status: .reading,  isFavorite: false, coverColor: .olive, accentColor: .bone),
            .init(title: "The Sea, the Sea",        author: "Iris Murdoch",          year: 1978, status: .shopping, coverColor: .rust,  accentColor: .bone),
            .init(title: "Pachinko",                author: "Min Jin Lee",           year: 2017, status: .shopping, coverColor: .clay,  accentColor: .bone),
            .init(title: "Station Eleven",          author: "Emily St. John Mandel", year: 2014, status: .shopping, coverColor: .sage,  accentColor: .cocoa),
            .init(title: "Gilead",                  author: "Marilynne Robinson",    year: 2004, status: .toread,   coverColor: .sand,  accentColor: .cocoa),
            .init(title: "Severance",               author: "Ling Ma",               year: 2018, status: .toread,   coverColor: .plum,  accentColor: .bone),
            .init(title: "Wolf Hall",               author: "Hilary Mantel",         year: 2009, status: .finished, isFavorite: true,  rating: 5, finishedDate: "Mar 2026", coverColor: .plum,  accentColor: .sand),
            .init(title: "Beloved",                 author: "Toni Morrison",         year: 1987, status: .finished, isFavorite: true,  rating: 5, finishedDate: "Feb 2026", coverColor: .rust,  accentColor: .bone),
            .init(title: "The Overstory",           author: "Richard Powers",        year: 2018, status: .finished, rating: 4, finishedDate: "Jan 2026", coverColor: .olive, accentColor: .bone),
            .init(title: "The Remains of the Day",  author: "Kazuo Ishiguro",        year: 1989, status: .finished, rating: 5, finishedDate: "Dec 2025", coverColor: .tea,   accentColor: .cocoa),
            .init(title: "To the Lighthouse",       author: "Virginia Woolf",        year: 1927, status: .finished, isFavorite: true,  rating: 5, finishedDate: "Oct 2025", coverColor: .sage,  accentColor: .cocoa),
        ]
        save()
    }

    private static let finishedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
}
