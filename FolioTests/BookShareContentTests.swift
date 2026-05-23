// BookShareContentTests.swift
// Unit tests for the share-text composer. Pure, deterministic, no I/O.

import Testing
@testable import Folio

@MainActor
struct BookShareContentTests {

    private func makeBook(title: String = "Piranesi",
                          author: String = "Susanna Clarke",
                          year: Int? = nil,
                          status: BookStatus,
                          rating: Int? = nil) -> Book {
        Book(title: title, author: author, year: year, status: status, rating: rating)
    }

    // MARK: - Finished

    @Test("Finished + rating + year produces the strongest recommendation")
    func finishedWithRatingAndYear() {
        let book = makeBook(year: 2020, status: .finished, rating: 5)
        let text = BookShareContent.text(for: book)
        #expect(text == #"Just finished "Piranesi" by Susanna Clarke (2020) — ⭐⭐⭐⭐⭐. Highly recommend!"#)
    }

    @Test("Finished + rating without year omits the parenthetical")
    func finishedWithRatingNoYear() {
        let book = makeBook(status: .finished, rating: 4)
        let text = BookShareContent.text(for: book)
        #expect(text == #"Just finished "Piranesi" by Susanna Clarke — ⭐⭐⭐⭐. Highly recommend!"#)
    }

    @Test("Finished without rating uses the softer phrasing")
    func finishedNoRating() {
        let book = makeBook(status: .finished)
        let text = BookShareContent.text(for: book)
        #expect(text == #"Just finished "Piranesi" by Susanna Clarke — worth a read."#)
    }

    @Test("Rating is clamped to 1–5 even with out-of-range values",
          arguments: [(0, 1), (1, 1), (3, 3), (5, 5), (7, 5), (-2, 1)])
    func ratingClamped(input: Int, expectedStars: Int) {
        let book = makeBook(status: .finished, rating: input)
        let text = BookShareContent.text(for: book)
        let stars = String(repeating: "⭐", count: expectedStars)
        #expect(text.contains(stars + "."), "Expected \(expectedStars) stars in: \(text)")
    }

    // MARK: - Other statuses

    @Test("Reading status produces a 'currently reading' message")
    func readingMessage() {
        let book = makeBook(status: .reading)
        let text = BookShareContent.text(for: book)
        #expect(text == #"Currently reading "Piranesi" by Susanna Clarke — looks great so far."#)
    }

    @Test("To-read and shopping share the same 'want to read' phrasing",
          arguments: [BookStatus.toread, .shopping])
    func wantToReadStatuses(status: BookStatus) {
        let book = makeBook(status: status)
        let text = BookShareContent.text(for: book)
        #expect(text == #"I want to read "Piranesi" by Susanna Clarke — heard it's great."#)
    }

    @Test("DNF status invites a second opinion")
    func dnfMessage() {
        let book = makeBook(status: .dnf)
        let text = BookShareContent.text(for: book)
        #expect(text == #"I started "Piranesi" by Susanna Clarke — let me know what you think."#)
    }

    // MARK: - Field plumbing

    @Test("Title and author appear verbatim in the output")
    func titleAuthorPassthrough() {
        let book = makeBook(title: "Cloud Atlas", author: "David Mitchell", status: .reading)
        let text = BookShareContent.text(for: book)
        #expect(text.contains("Cloud Atlas"))
        #expect(text.contains("David Mitchell"))
    }

    @Test("Year appears in parentheses only when set")
    func yearOptional() {
        let withYear = makeBook(year: 1984, status: .finished, rating: 3)
        let withoutYear = makeBook(status: .finished, rating: 3)
        #expect(BookShareContent.text(for: withYear).contains("(1984)"))
        #expect(!BookShareContent.text(for: withoutYear).contains("("))
    }
}
