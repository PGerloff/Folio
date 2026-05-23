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

    /// Surfaced to the UI so the user sees disk/decode failures instead of
    /// silently losing data. Cleared after the alert is dismissed.
    var lastErrorMessage: String?

    private let storeURL: URL
    private let coversDir: URL

    /// In-memory cache of decoded cover images, keyed by filename.
    /// Avoids re-reading + re-decoding JPEGs on every SwiftUI view recompute.
    /// NSCache is thread-safe and auto-evicts under memory pressure.
    @ObservationIgnored private let coverCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        return c
    }()

    /// - Parameter documentsDirectory: Override the documents directory for
    ///   testing. In production this stays nil and the real Documents/ is used.
    init(documentsDirectory: URL? = nil) {
        let docs = documentsDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
            invalidateCoverCache(name)
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
                invalidateCoverCache(old)
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
    ///
    /// `@MainActor` because `BookStore` is `@Observable` — all reads/writes of
    /// `books` must happen on the main actor. The `await`s on URLSession suspend
    /// off-main automatically, so this doesn't block the UI.
    @MainActor
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

        guard let (searchData, _) = try? await URLSession.shared.data(for: OpenLibrary.request(searchURL)),
              let result = try? JSONDecoder().decode(OLSearchResponse.self, from: searchData),
              let coverId = result.docs.first?.cover_i else { return }

        // Step 2 — fetch the medium-size JPEG. `?default=false` makes Open
        // Library return a 404 instead of a 1×1 placeholder when no cover exists.
        guard let coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg?default=false") else { return }

        guard let (imageData, response) = try? await URLSession.shared.data(for: OpenLibrary.request(coverURL)),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              !imageData.isEmpty else { return }

        // Step 3 — persist, but only if the user hasn't added a photo in the
        // meantime.
        guard let now = book(bookId), now.photoFilename == nil else { return }
        setPhoto(bookId, data: imageData)
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

    /// Returns a `UIImage` for the cover file, decoded once and cached.
    /// Called from `CoverView.body` on every render, so it MUST be cheap.
    func loadCoverImage(_ filename: String) -> UIImage? {
        let key = filename as NSString
        if let cached = coverCache.object(forKey: key) { return cached }
        let url = coversDir.appendingPathComponent(filename)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        coverCache.setObject(image, forKey: key)
        return image
    }

    /// Drop a cached image (call when its file is deleted or replaced).
    private func invalidateCoverCache(_ filename: String?) {
        guard let filename else { return }
        coverCache.removeObject(forKey: filename as NSString)
    }

    private func writePhoto(data: Data, for bookId: UUID) -> String? {
        // Re-encode as JPEG @ 0.85 to keep file size sane. If the input data
        // isn't decodable as an image (HEIC mishap, corrupted blob, non-image
        // bytes), fail loudly rather than persist garbage that will silently
        // fail to render forever.
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            lastErrorMessage = "Couldn't save that photo — the file wasn't a readable image."
            return nil
        }
        let filename = "\(bookId.uuidString).jpg"
        let url = coversDir.appendingPathComponent(filename)
        do {
            try jpeg.write(to: url, options: .atomic)
            return filename
        } catch {
            lastErrorMessage = "Couldn't save that photo: \(error.localizedDescription)"
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
        do {
            let data = try encoder.encode(payload)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Surface disk-write failures to the UI. The user needs to know
            // their change might not survive an app restart.
            lastErrorMessage = "Couldn't save your library: \(error.localizedDescription)"
        }
    }

    private func load() {
        // First-launch case — no file yet.
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        let data: Data
        do {
            data = try Data(contentsOf: storeURL)
        } catch {
            lastErrorMessage = "Couldn't read your library file: \(error.localizedDescription)"
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let payload = try decoder.decode(Persisted.self, from: data)
            self.books = payload.books
            self.favoriteAuthors = Set(payload.favoriteAuthors)
        } catch {
            // Corrupted JSON. Back the file up BEFORE the next save() overwrites
            // it — keeps the user's data recoverable.
            backupCorruptedStore()
            lastErrorMessage = "Your library file was unreadable and has been backed up. The library has been reset."
        }
    }

    private func backupCorruptedStore() {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = storeURL
            .deletingPathExtension()
            .appendingPathExtension("corrupted-\(stamp).json")
        try? FileManager.default.moveItem(at: storeURL, to: backupURL)
    }

    func resetLibrary() {
        for book in books {
            if let name = book.photoFilename {
                try? FileManager.default.removeItem(at: coversDir.appendingPathComponent(name))
            }
        }
        coverCache.removeAllObjects()
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
