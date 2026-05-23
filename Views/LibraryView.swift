// LibraryView.swift — owned books, with filter chips

import SwiftUI

struct LibraryView: View {
    @Environment(BookStore.self) private var store
    let openBook: (UUID) -> Void

    enum Filter: Hashable {
        case all, toread, reading, finished, favorites
        var label: String {
            switch self {
            case .all: return "All"
            case .toread: return "To Read"
            case .reading: return "Reading"
            case .finished: return "Finished"
            case .favorites: return "Favorites"
            }
        }
    }

    @State private var filter: Filter = .all

    private var visible: [Book] {
        switch filter {
        case .all:       return store.owned.sorted { $0.isFavorite && !$1.isFavorite }
        case .toread:    return store.books(status: .toread)
        case .reading:   return store.books(status: .reading)
        case .finished:  return store.books(status: .finished)
        case .favorites: return store.owned.filter { $0.isFavorite }
        }
    }

    /// One pass through `owned` covers every chip's count, instead of five
    /// independent O(n) filter passes per render.
    private var chipCounts: [Filter: Int] {
        let owned = store.owned
        var counts: [Filter: Int] = [.all: owned.count,
                                     .toread: 0, .reading: 0,
                                     .finished: 0, .favorites: 0]
        for book in owned {
            if book.isFavorite { counts[.favorites, default: 0] += 1 }
            switch book.status {
            case .toread:   counts[.toread, default: 0] += 1
            case .reading:  counts[.reading, default: 0] += 1
            case .finished: counts[.finished, default: 0] += 1
            default: break
            }
        }
        return counts
    }

    private let cols = [GridItem(.flexible(), spacing: 18),
                        GridItem(.flexible(), spacing: 18),
                        GridItem(.flexible(), spacing: 18)]

    var body: some View {
        // Cache the counts dict for this render — used by every chip.
        let counts = chipCounts
        return NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    MetaLabel(text: "Your books")
                    Text("Library")
                        .font(.folioDisplay(36))
                        .kerning(-0.7)
                        .foregroundStyle(Folio.ink1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([Filter.all, .toread, .reading, .favorites, .finished], id: \.self) { f in
                            FilterChip(label: f.label, count: counts[f] ?? 0,
                                       isOn: filter == f) { filter = f }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 8)

                if visible.isEmpty {
                    VStack {
                        Spacer(minLength: 24)
                        Text("Nothing here yet.")
                            .font(.folioUI(13))
                            .foregroundStyle(Folio.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Folio.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            )
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 24) {
                            ForEach(visible) { book in
                                Button { openBook(book.id) } label: {
                                    LibraryTile(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background(Folio.paper0.ignoresSafeArea())
        }
    }
}

private struct FilterChip: View {
    let label: String
    let count: Int
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(label)
                Text("\(count)").font(.folioMono(10)).opacity(0.6)
            }
            .font(.folioUI(13, weight: .medium))
            .foregroundStyle(isOn ? Folio.paper0 : Folio.ink2)
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background(
                Capsule().fill(isOn ? Folio.ink1 : .clear)
            )
            .overlay(
                Capsule().strokeBorder(Folio.paperEdge, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryTile: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                CoverView(book, width: geo.size.width)
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(Folio.statusDot(book.status))
                            .frame(width: 6, height: 6)
                            .overlay(Circle().strokeBorder(Folio.paper0.opacity(0.8), lineWidth: 1.5))
                            .padding(6)
                    }
                    .overlay(alignment: .topTrailing) {
                        if book.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Folio.rust)
                                .padding(6)
                        }
                    }
            }
            .aspectRatio(2.0/3.0, contentMode: .fit)

            Text(book.title)
                .font(.folioDisplay(12))
                .foregroundStyle(Folio.ink1)
                .lineLimit(2)
            Text(book.lastNameOfAuthor)
                .font(.folioUI(10))
                .foregroundStyle(Folio.ink3)
            if let rating = book.rating {
                StarsView(rating: rating, size: 8, color: Folio.ink2)
            }
        }
    }
}
