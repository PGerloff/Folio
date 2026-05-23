// OpenLibraryCoverFetchTests.swift
// Tests for BookStore.fetchCoverFromOpenLibrary using a stub URLProtocol
// that intercepts requests on an injected URLSession. No real network I/O.

import Testing
import Foundation
import UIKit
@testable import Bedside

/// Serialized because all tests in this suite share `MockURLProtocol.handler`
/// (a static) — running them in parallel would let one test's handler clobber
/// another's mid-run.
@MainActor
@Suite(.serialized)
struct OpenLibraryCoverFetchTests {

    // MARK: - Helpers

    private func tempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("BedsideTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        MockURLProtocol.reset()
    }

    /// Thread-safe sample JPEG via `UIGraphicsImageRenderer`. The legacy
    /// `UIGraphicsBeginImageContext` API is not thread-safe and corrupts
    /// state when Swift Testing runs tests in parallel.
    private func sampleJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    private func makeMockedStore(documentsDirectory: URL) -> BookStore {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return BookStore(documentsDirectory: documentsDirectory, urlSession: session)
    }

    // MARK: - Tests

    @Test("Successful search + cover download populates photoFilename")
    func happyPath() async throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        // Stub the two endpoints fetchCoverFromOpenLibrary hits:
        let searchJSON = #"{"docs":[{"cover_i":12345}]}"#.data(using: .utf8)!
        let coverData = sampleJPEG()
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url.contains("openlibrary.org/search.json") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!, searchJSON)
            }
            if url.contains("covers.openlibrary.org") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!, coverData)
            }
            throw URLError(.unsupportedURL)
        }

        let store = makeMockedStore(documentsDirectory: dir)
        let id = store.addBook(title: "Piranesi", author: "Susanna Clarke")

        await store.fetchCoverFromOpenLibrary(for: id, title: "Piranesi", author: "Susanna Clarke")

        let book = try #require(store.book(id))
        #expect(book.photoFilename != nil, "photoFilename should be populated after successful fetch")
        let filename = try #require(book.photoFilename)
        #expect(store.loadCoverImage(filename) != nil)
    }

    @Test("No search match leaves photoFilename nil")
    func noSearchMatch() async throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let emptySearch = #"{"docs":[]}"#.data(using: .utf8)!
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200,
                            httpVersion: nil, headerFields: nil)!, emptySearch)
        }

        let store = makeMockedStore(documentsDirectory: dir)
        let id = store.addBook(title: "Unknown Title", author: "Nobody")

        await store.fetchCoverFromOpenLibrary(for: id, title: "Unknown Title", author: "Nobody")

        #expect(store.book(id)?.photoFilename == nil)
    }

    @Test("404 on cover URL leaves photoFilename nil")
    func coverNotFound() async throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        let searchJSON = #"{"docs":[{"cover_i":99999}]}"#.data(using: .utf8)!
        MockURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url.contains("openlibrary.org/search.json") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!, searchJSON)
            }
            // Cover endpoint returns 404 (Open Library does this when ?default=false
            // and the cover doesn't exist).
            return (HTTPURLResponse(url: request.url!, statusCode: 404,
                                   httpVersion: nil, headerFields: nil)!, Data())
        }

        let store = makeMockedStore(documentsDirectory: dir)
        let id = store.addBook(title: "Piranesi", author: "Susanna Clarke")

        await store.fetchCoverFromOpenLibrary(for: id, title: "Piranesi", author: "Susanna Clarke")

        #expect(store.book(id)?.photoFilename == nil)
    }

    @Test("Network error is swallowed silently")
    func networkError() async throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let store = makeMockedStore(documentsDirectory: dir)
        let id = store.addBook(title: "Anything", author: "Anyone")

        await store.fetchCoverFromOpenLibrary(for: id, title: "Anything", author: "Anyone")

        #expect(store.book(id)?.photoFilename == nil)
        // Cover fetch failures are deliberately silent — they're a nice-to-have
        // background enrichment, not a user-facing operation.
        #expect(store.lastErrorMessage == nil)
    }

    @Test("Skips entirely when the book already has a photo")
    func skipIfPhotoExists() async throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: nil)!, Data())
        }

        let store = makeMockedStore(documentsDirectory: dir)
        let id = store.addBook(title: "Has Photo", author: "Author")
        store.setPhoto(id, data: sampleJPEG())

        await store.fetchCoverFromOpenLibrary(for: id, title: "Has Photo", author: "Author")

        #expect(requestCount == 0, "No network calls should be made when a photo already exists")
    }

    @Test("Skips when author is empty or 'Unknown'",
          arguments: ["", "  ", "Unknown", "unknown", "UNKNOWN"])
    func skipForBadAuthor(badAuthor: String) async throws {
        let dir = try tempDir()
        defer { cleanup(dir) }

        var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: nil)!, Data())
        }

        let store = makeMockedStore(documentsDirectory: dir)
        let id = store.addBook(title: "A Title", author: "Real Author")

        await store.fetchCoverFromOpenLibrary(for: id, title: "A Title", author: badAuthor)

        #expect(requestCount == 0, "Should not hit the network for non-discoverable authors")
    }
}

// MARK: - MockURLProtocol

/// URLProtocol stub for intercepting URLSession requests in tests.
/// Set `MockURLProtocol.handler` to a closure that returns (response, data)
/// or throws. Always call `MockURLProtocol.reset()` between tests.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
