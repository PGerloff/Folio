// CoverView.swift — renders the book cover (photo if present, otherwise tile)

import SwiftUI

struct CoverView: View {
    @Environment(BookStore.self) private var store

    let book: Book
    /// Explicit width — height derives from 2:3 aspect ratio.
    let width: CGFloat

    init(_ book: Book, width: CGFloat) {
        self.book = book
        self.width = width
    }

    var body: some View {
        ZStack {
            // Placeholder always rendered underneath; real photo fades in on top.
            // This produces a smooth cross-fade when an Open Library cover arrives
            // (L-5) instead of the previous instant "pop".
            placeholder

            if let name = book.photoFilename, let uiImage = store.loadCoverImage(name) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: book.photoFilename)
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            // edge wear gradient
            LinearGradient(
                colors: [.white.opacity(0.06), .clear, .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.black.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 5, x: 1.5, y: 3)
    }

    private var placeholder: some View {
        ZStack {
            Bedside.coverColor(book.coverColor)

            // spine hint
            HStack(spacing: 0) {
                Spacer().frame(width: width * 0.08)
                Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                Spacer()
            }

            VStack(alignment: .leading) {
                Text(book.lastNameOfAuthor.uppercased())
                    .font(.bedsideMono(max(7, width * 0.038)))
                    .tracking(width * 0.038 * 0.18 * 10)
                    .foregroundStyle(Bedside.coverColor(book.accentColor).opacity(0.7))
                Spacer()
                Text(book.title)
                    .font(.bedsideDisplay(max(11, width * 0.135), weight: .medium))
                    .lineSpacing(-2)
                    .tracking(-(width * 0.135 * 0.02))
                    .foregroundStyle(Bedside.coverColor(book.accentColor))
                Spacer()
                HStack {
                    Text("·")
                    Spacer()
                    if let year = book.year { Text(String(year)) }
                }
                .font(.bedsideMono(max(7, width * 0.034)))
                .tracking(width * 0.034 * 0.18 * 10)
                .foregroundStyle(Bedside.coverColor(book.accentColor).opacity(0.55))
            }
            .padding(EdgeInsets(top: width * 0.10, leading: width * 0.10,
                                bottom: width * 0.12, trailing: width * 0.10))
        }
    }
}
