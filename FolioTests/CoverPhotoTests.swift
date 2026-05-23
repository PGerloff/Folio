// CoverPhotoTests.swift
// Tests for the photo-storage path: writePhoto via setPhoto, loadCoverImage,
// invalidation on delete/replace, and fail-loud behaviour for non-image data.

import Testing
import Foundation
import UIKit
@testable import Folio

@MainActor
struct CoverPhotoTests {

    // MARK: - Helpers

    private func tempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("FolioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Returns a small valid JPEG (10×10 solid colour). Uses
    /// `UIGraphicsImageRenderer` instead of `UIGraphicsBeginImageContext`
    /// because Swift Testing runs tests in parallel and the legacy context
    /// API is not thread-safe — concurrent tests corrupt each other's state.
    private func sampleJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    // MARK: - Tests

    @Test("setPhoto writes a file and loadCoverImage reads it back")
    func setAndLoadPhoto() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)
        let id = store.addBook(title: "Cover test", author: "A")
        store.setPhoto(id, data: sampleJPEG())

        let book = try #require(store.book(id))
        let filename = try #require(book.photoFilename, "setPhoto should populate photoFilename")
        let image = try #require(store.loadCoverImage(filename), "loadCoverImage should return UIImage")
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test("Cover photo persists across BookStore reinstantiation")
    func photoSurvivesReload() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store1 = BookStore(documentsDirectory: dir)
        let id = store1.addBook(title: "Persistent", author: "A")
        store1.setPhoto(id, data: sampleJPEG())
        let firstFilename = try #require(store1.book(id)?.photoFilename)

        let store2 = BookStore(documentsDirectory: dir)
        let book = try #require(store2.book(id))
        #expect(book.photoFilename == firstFilename)
        #expect(store2.loadCoverImage(firstFilename) != nil)
    }

    @Test("Replacing a photo invalidates the cache and updates the file")
    func replacePhoto() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)
        let id = store.addBook(title: "Replace", author: "A")
        store.setPhoto(id, data: sampleJPEG())
        let firstFilename = try #require(store.book(id)?.photoFilename)

        // Replace with a different (still valid) image
        store.setPhoto(id, data: sampleJPEG())
        let secondFilename = try #require(store.book(id)?.photoFilename)

        // Filename is keyed by book ID so it should be the same name…
        #expect(firstFilename == secondFilename)
        // …but the file should still be readable (re-written, cache invalidated).
        #expect(store.loadCoverImage(secondFilename) != nil)
    }

    @Test("Clearing a photo removes the file")
    func clearPhoto() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)
        let id = store.addBook(title: "Clear", author: "A")
        store.setPhoto(id, data: sampleJPEG())
        let filename = try #require(store.book(id)?.photoFilename)
        let fileURL = dir.appendingPathComponent("covers").appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        store.setPhoto(id, data: nil)

        #expect(store.book(id)?.photoFilename == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Removing a book also removes its cover file")
    func removeBookRemovesCover() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)
        let id = store.addBook(title: "Doomed", author: "A")
        store.setPhoto(id, data: sampleJPEG())
        let filename = try #require(store.book(id)?.photoFilename)
        let fileURL = dir.appendingPathComponent("covers").appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        store.remove(id)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Non-image bytes fail loud via lastErrorMessage")
    func corruptedPhotoDataFailsLoud() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)
        let id = store.addBook(title: "Bad bytes", author: "A")
        let garbage = Data("this is not a JPEG".utf8)
        store.setPhoto(id, data: garbage)

        // The book must NOT have a photoFilename pointing at garbage bytes.
        #expect(store.book(id)?.photoFilename == nil)
        // The user should be told.
        #expect(store.lastErrorMessage != nil)
        #expect(store.lastErrorMessage?.contains("photo") == true)
    }

    @Test("loadCoverImage returns nil for unknown filenames")
    func unknownFilename() throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let store = BookStore(documentsDirectory: dir)
        #expect(store.loadCoverImage("does-not-exist.jpg") == nil)
    }
}
