// OpenLibrary.swift — shared config for all Open Library API calls.
//
// Open Library asks identified apps to include a User-Agent header
// (https://openlibrary.org/developers/api#dos) — this lifts the rate limit
// from 1 req/s to 3 req/s. Centralising the header here also means the
// short network timeout below is applied uniformly.

import Foundation

enum OpenLibrary {
    /// Identifies this app to Open Library per their guidelines.
    /// Format is: AppName/Version (contact).
    static let userAgent = "Folio/1.0 (nodabs@gmail.com)"

    /// Default request timeout. Open Library is usually fast; if a request
    /// hangs past this the user is better served by an empty result than
    /// by a spinner that hangs for the URLSession default of 60s.
    static let timeout: TimeInterval = 10

    /// Build a request with the required User-Agent and a short timeout.
    static func request(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url,
                             cachePolicy: .useProtocolCachePolicy,
                             timeoutInterval: timeout)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return req
    }
}
