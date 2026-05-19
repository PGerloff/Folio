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

    /// Try to find a cover on Open Library by title + author and download it.
    /// Silently no-ops if the book already has a photo, the search returns no
    /// match, or the network fails.
    ///
    /// Uses the medium ("M", ~180px wide) cover size to keep payloads small
    /// — typical M cover is 5–15 KB; large ("L") is 30–80 KB.
    func fetchCoverFromOpenLibrary(for bookId: UUID, title: String, author: String) async {
        // Guards
        guard let current = book(bookId), current.photoFilename == nil else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !author.isEmpty,
              author.caseInsensitiveCompare("Unknown") != .orderedSame else { return }

        // Step 1 — search for the work, ask only for the cover_i field.
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            .init(name: "title",  value: title),
            .init(name: "author", value: author),
            .init(name: "limit",  value: "1"),
            .init(name: "fields", value: "cover_i")
        ]
        guard let searchURL = components.url else { return }

        var searchRequest = URLRequest(url: searchURL)
        searchRequest.setValue("Folio/1.0 (nodabs@gmail.com)", forHTTPHeaderField: "User-Agent")

        guard let (searchData, _) = try? await URLSession.shared.data(for: searchRequest),
              let result = try? JSONDecoder().decode(OLSearchResponse.self, from: searchData),
              let coverId = result.docs.first?.cover_i else { return }

        // Step 2 — fetch the medium-size JPEG. `?default=false` makes Open
        // Library return a 404 instead of a 1×1 placeholder when no cover exists.
        guard let coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg?default=false") else { return }

        var coverRequest = URLRequest(url: coverURL)
        coverRequest.setValue("Folio/1.0 (nodabs@gmail.com)", forHTTPHeaderField: "User-Agent")

        guard let (imageData, response) = try? await URLSession.shared.data(for: coverRequest),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              !imageData.isEmpty else { return }

        // Step 3 — persist, but only if the user hasn't added a photo in the
        // meantime. Bounce to main to mutate the @Observable store consistently.
        await MainActor.run {
            guard let now = book(bookId), now.photoFilename == nil else { return }
            setPhoto(bookId, data: imageData)
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

    func resetLibrary() {
        for book in books {
            if let name = book.photoFilename {
                try? FileManager.default.removeItem(at: coversDir.appendingPathComponent(name))
            }
        }
        books.removeAll()
        favoriteAuthors.removeAll()
        save()
    }

    private static let finishedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
}

// MARK: - Open Library response

private struct OLSearchResponse: Decodable {
    struct Doc: Decodable { let cover_i: Int? }
    let docs: [Doc]
}
