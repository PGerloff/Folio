// BookStorePersistenceTests.swift
// Round-trip tests for BookStore JSON persistence. Each test runs in its own
// temporary directory so they're isolated from production data and from each
// other.

import Testing
import Foundation
@testable import Bedside

@MainActor
struct BookStorePersistenceTests {

    // MARK: - Helpers

    /// Returns a fresh temporary directory for a single test run.
    /// The directory is removed at the end of the test scope.
    private func tempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("BedsideTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Tests

    @Test("Adding a book persists across reload")
    func addBookRoundTrip() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store1 = BookStore(documentsDirectory: dir)
        let id = store1.addBook(title: "Piranesi", author: "Susanna Clarke",
                                year: 2020, status: .reading)

        // Reload from disk into a brand-new store instance.
        let store2 = BookStore(documentsDirectory: dir)

        #expect(store2.books.count == 1)
        let loaded = try #require(store2.book(id))
        #expect(loaded.title == "Piranesi")
        #expect(loaded.author == "Susanna Clarke")
        #expect(loaded.year == 2020)
        #expect(loaded.status == .reading)
    }

    @Test("Updating a book persists across reload")
    func updateRoundTrip() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store1 = BookStore(documentsDirectory: dir)
        let id = store1.addBook(title: "Dune", author: "Frank Herbert", status: .toread)
        store1.setStatus(id, .finished)
        store1.setRating(id, 5)
        store1.toggleFavorite(id)

        let store2 = BookStore(documentsDirectory: dir)
        let loaded = try #require(store2.book(id))

        #expect(loaded.status == .finished)
        #expect(loaded.rating == 5)
        #expect(loaded.isFavorite == true)
        #expect(loaded.finishedDate != nil, "finishedDate should be set on first .finished transition")
    }

    @Test("Removing a book persists across reload")
    func removeRoundTrip() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store1 = BookStore(documentsDirectory: dir)
        let keep = store1.addBook(title: "Keep me", author: "Author A")
        let drop = store1.addBook(title: "Drop me", author: "Author B")
        store1.remove(drop)

        let store2 = BookStore(documentsDirectory: dir)

        #expect(store2.books.count == 1)
        #expect(store2.book(keep) != nil)
        #expect(store2.book(drop) == nil)
    }

    @Test("Notes round-trip correctly")
    func notesRoundTrip() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store1 = BookStore(documentsDirectory: dir)
        let id = store1.addBook(title: "Notes test", author: "A")
        store1.addNote(id, text: "First note")
        store1.addNote(id, text: "Second note")

        let store2 = BookStore(documentsDirectory: dir)
        let loaded = try #require(store2.book(id))

        #expect(loaded.notes.count == 2)
        // Notes are inserted at index 0, so most recent is first.
        #expect(loaded.notes.first?.text == "Second note")
        #expect(loaded.notes.last?.text == "First note")
    }

    @Test("Favourite authors persist across reload")
    func favouriteAuthorsRoundTrip() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store1 = BookStore(documentsDirectory: dir)
        store1.toggleFavoriteAuthor("Ursula K. Le Guin")
        store1.toggleFavoriteAuthor("Italo Calvino")

        let store2 = BookStore(documentsDirectory: dir)

        #expect(store2.favoriteAuthors.contains("Ursula K. Le Guin"))
        #expect(store2.favoriteAuthors.contains("Italo Calvino"))
        #expect(store2.favoriteAuthors.count == 2)
    }

    @Test("Corrupted JSON triggers backup and reset")
    func corruptedStoreBackup() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        // Write garbage to the store file before any BookStore touches it.
        let storeURL = dir.appendingPathComponent("bedside.json")
        try "this is not valid JSON".write(to: storeURL, atomically: true, encoding: .utf8)

        let store = BookStore(documentsDirectory: dir)

        // Library should be reset.
        #expect(store.books.isEmpty)
        #expect(store.favoriteAuthors.isEmpty)
        // User-facing error should be surfaced.
        #expect(store.lastErrorMessage != nil)

        // A backup file should exist with the original garbage preserved.
        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let backups = contents.filter { $0.hasPrefix("bedside.corrupted-") && $0.hasSuffix(".json") }
        #expect(backups.count == 1, "expected exactly one backup file")
    }

    @Test("Legacy folio.json is migrated to bedside.json on first launch")
    func legacyFileMigration() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        // Seed a legacy folio.json by creating a store with the old name,
        // saving data, then writing those bytes back as folio.json before
        // the migrating store starts.
        let seed = BookStore(documentsDirectory: dir)
        _ = seed.addBook(title: "Migrated Book", author: "An Old Friend", status: .reading)
        let bedsideURL = dir.appendingPathComponent("bedside.json")
        let legacyURL = dir.appendingPathComponent("folio.json")
        try FileManager.default.moveItem(at: bedsideURL, to: legacyURL)

        // Sanity check: bedside.json missing, folio.json present.
        #expect(!FileManager.default.fileExists(atPath: bedsideURL.path))
        #expect(FileManager.default.fileExists(atPath: legacyURL.path))

        // A new store should migrate the legacy file in and read the data.
        let migrated = BookStore(documentsDirectory: dir)
        #expect(migrated.books.count == 1)
        #expect(migrated.books.first?.title == "Migrated Book")
        // After migration, the legacy file is gone and the new one exists.
        #expect(FileManager.default.fileExists(atPath: bedsideURL.path))
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test("First launch (no file) loads an empty library cleanly")
    func firstLaunch() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)

        #expect(store.books.isEmpty)
        #expect(store.favoriteAuthors.isEmpty)
        #expect(store.lastErrorMessage == nil)
    }
}
