// YouView.swift — stats, favorite authors, favorite books, settings

import SwiftUI

struct YouView: View {
    @Environment(BookStore.self) private var store
    let openBook: (UUID) -> Void

    @State private var confirmReset = false

    private var stats: [(label: String, value: Int)] {
        [
            ("Read",    store.books(status: .finished).count),
            ("Reading", store.books(status: .reading).count),
            ("To read", store.books(status: .toread).count),
            ("On list", store.books(status: .shopping).count),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    statsGrid
                    favoriteAuthors
                    if !store.favorites.isEmpty { favoriteBooks }
                    settings
                    Text("Folio · Beta")
                        .font(.folioMono(9))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Folio.ink4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(Folio.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .alert("Reset to sample library?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { store.resetToSeed() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your changes will be lost.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: "Profile")
            Text("You")
                .font(.folioDisplay(36))
                .kerning(-0.7)
                .foregroundStyle(Folio.ink1)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(stats, id: \.label) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stat.value)")
                        .font(.folioDisplay(24))
                        .kerning(-0.5)
                        .foregroundStyle(Folio.ink1)
                    MetaLabel(text: stat.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Folio.paper1)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
                )
            }
        }
    }

    private var favoriteAuthors: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "Favorite authors · \(store.favoriteAuthors.count)")
            if store.favoriteAuthors.isEmpty {
                Text("Tap the heart next to an author's name on a book detail page.")
                    .font(.folioUI(12))
                    .foregroundStyle(Folio.ink3)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(store.favoriteAuthors).sorted(), id: \.self) { name in
                        Button { store.toggleFavoriteAuthor(name) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Folio.rust)
                                Text(name)
                            }
                            .font(.folioDisplay(13).italic())
                            .foregroundStyle(Folio.ink1)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Folio.paper1)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Folio.paperEdge, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var favoriteBooks: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "Favorite books · \(store.favorites.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.favorites) { book in
                        Button { openBook(book.id) } label: {
                            CoverView(book, width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel(text: "Settings").padding(.bottom, 6)
            settingsRow("Notifications")
            settingsRow("Display & theme")
            settingsRow("Export library")
            settingsRow("Reset to sample data", isLast: true) { confirmReset = true }
        }
    }

    private func settingsRow(_ label: String, isLast: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(label).font(.folioUI(15)).foregroundStyle(Folio.ink1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Folio.ink3)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Folio.paperEdge).frame(height: 0.5) }
        }
    }
}

// MARK: - Simple flow layout (for chip wrapping)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
