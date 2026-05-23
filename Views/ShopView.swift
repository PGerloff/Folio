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
                                Rectangle().fill(Bedside.paperEdge).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .background(Bedside.paper0.ignoresSafeArea())
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
                    .font(.bedsideDisplay(36))
                    .kerning(-0.7)
                    .foregroundStyle(Bedside.ink1)
                Spacer()
                let count = shopping.count
                Text("\(count) \(count == 1 ? "BOOK" : "BOOKS")")
                    .font(.bedsideMono(12))
                    .tracking(0.7)
                    .foregroundStyle(Bedside.ink3)
            }

            Button { showAdd = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add a book")
                }
                .font(.bedsideUI(14, weight: .medium))
                .foregroundStyle(Color(hex: 0xF5ECD8))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Bedside.sienna))
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
                .foregroundStyle(Bedside.ink4)
            Text("Nothing on the list yet")
                .font(.bedsideDisplay(18))
                .foregroundStyle(Bedside.ink2)
            Text("Books you want to buy will appear here.")
                .font(.bedsideUI(12))
                .foregroundStyle(Bedside.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Bedside.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
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
                        .font(.bedsideDisplay(16))
                        .foregroundStyle(Bedside.ink1)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.bedsideUI(12))
                        .foregroundStyle(Bedside.ink3)
                }
                Spacer()
                Button(action: onBought) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.sienna)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Bedside.sienna, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark as bought")
            }
        }
        .buttonStyle(.plain)
    }
}
