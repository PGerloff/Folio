// HomeView.swift — landing screen with shopping-first CTA

import SwiftUI

struct HomeView: View {
    @Environment(BookStore.self) private var store
    @Binding var showAdd: Bool
    let openBook: (UUID) -> Void
    let switchTo: (Tab) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    shoppingCTA

                    if !store.books(status: .reading).isEmpty {
                        currentlyReading
                    }

                    shoppingPreview

                    if !store.favorites.filter({ $0.status == .finished }).isEmpty {
                        favorites
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Folio.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: "Your reading")
            Text("Folio.")
                .font(.folioDisplay(44))
                .foregroundStyle(Folio.ink1)
                .kerning(-1)
        }
        .padding(.top, 8)
    }

    private var shoppingCTA: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add to shopping list")
                        .font(.folioDisplay(18))
                    MetaLabel(text: "For next time you're out")
                        .opacity(0.85)
                }
                .foregroundStyle(Color(hex: 0xF5ECD8))

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF5ECD8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Folio.sienna)
            )
        }
        .buttonStyle(.plain)
    }

    private var currentlyReading: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                MetaLabel(text: "Currently reading")
                Spacer()
                let count = store.books(status: .reading).count
                Text("\(count) \(count == 1 ? "BOOK" : "BOOKS")")
                    .font(.folioMono(10))
                    .tracking(0.8)
                    .foregroundStyle(Folio.ink3)
            }

            VStack(spacing: 14) {
                ForEach(store.books(status: .reading)) { book in
                    Button { openBook(book.id) } label: {
                        HStack(spacing: 14) {
                            CoverView(book, width: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(book.title)
                                        .font(.folioDisplay(18))
                                        .foregroundStyle(Folio.ink1)
                                        .lineLimit(2)
                                    if book.isFavorite {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Folio.rust)
                                    }
                                }
                                Text(book.author)
                                    .font(.folioUI(12))
                                    .foregroundStyle(Folio.ink3)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Folio.ink3)
                        }
                        .padding(14)
                        .background(Folio.paper1)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shoppingPreview: some View {
        let books = store.books(status: .shopping)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                MetaLabel(text: "On your shopping list")
                Spacer()
                Button {
                    switchTo(.shop)
                } label: {
                    HStack(spacing: 4) {
                        Text("SEE ALL · \(books.count)")
                        Image(systemName: "chevron.right").font(.system(size: 9))
                    }
                    .font(.folioMono(10))
                    .tracking(0.8)
                    .foregroundStyle(Folio.ink3)
                }
            }

            if books.isEmpty {
                Text("Nothing yet. Tap \"Add to shopping list\" above.")
                    .font(.folioUI(13))
                    .foregroundStyle(Folio.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Folio.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(books.prefix(6)) { book in
                            Button { openBook(book.id) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverView(book, width: 86)
                                    Text(book.title)
                                        .font(.folioDisplay(12))
                                        .foregroundStyle(Folio.ink1)
                                        .lineLimit(2)
                                        .frame(width: 86, alignment: .leading)
                                    Text(book.lastNameOfAuthor)
                                        .font(.folioUI(10))
                                        .foregroundStyle(Folio.ink3)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var favorites: some View {
        let favs = store.favorites.filter { $0.status == .finished }
        return VStack(alignment: .leading, spacing: 14) {
            MetaLabel(text: "Favorites")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favs) { book in
                        Button { openBook(book.id) } label: {
                            CoverView(book, width: 72)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Folio.rust)
                                        .padding(4)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
