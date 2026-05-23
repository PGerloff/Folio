// ShopView.swift — the shopping list (books to buy)

import SwiftUI

struct ShopView: View {
    @Environment(BookStore.self) private var store
    @Binding var showAdd: Bool
    let openBook: (UUID) -> Void

    var body: some View {
        // One filter pass per render instead of three.
        let shopping = store.books(status: .shopping)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(shopping: shopping)

                    if shopping.isEmpty {
                        emptyState
                    } else {
                        ForEach(shopping) { book in
                            ShopRow(book: book,
                                    onTap: { openBook(book.id) },
                                    onBought: { store.setStatus(book.id, .toread) })
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .overlay(alignment: .top) {
                                Rectangle().fill(Folio.paperEdge).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .background(Folio.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            // Success haptic when a shopping-list item is moved to To Read.
            .sensoryFeedback(.success, trigger: shopping.count)
        }
    }

    private func header(shopping: [Book]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: "Shopping list")
            HStack(alignment: .firstTextBaseline) {
                Text("Add")
                    .font(.folioDisplay(36))
                    .kerning(-0.7)
                    .foregroundStyle(Folio.ink1)
                Spacer()
                let count = shopping.count
                Text("\(count) \(count == 1 ? "BOOK" : "BOOKS")")
                    .font(.folioMono(12))
                    .tracking(0.7)
                    .foregroundStyle(Folio.ink3)
            }

            Button { showAdd = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add a book")
                }
                .font(.folioUI(14, weight: .medium))
                .foregroundStyle(Color(hex: 0xF5ECD8))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Folio.sienna))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundStyle(Folio.ink4)
            Text("Nothing on the list yet")
                .font(.folioDisplay(18))
                .foregroundStyle(Folio.ink2)
            Text("Books you want to buy will appear here.")
                .font(.folioUI(12))
                .foregroundStyle(Folio.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Folio.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
        )
        .padding(24)
    }
}

private struct ShopRow: View {
    let book: Book
    let onTap: () -> Void
    let onBought: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                CoverView(book, width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.folioDisplay(16))
                        .foregroundStyle(Folio.ink1)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.folioUI(12))
                        .foregroundStyle(Folio.ink3)
                }
                Spacer()
                Button(action: onBought) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Folio.sienna)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Folio.sienna, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark as bought")
            }
        }
        .buttonStyle(.plain)
    }
}
