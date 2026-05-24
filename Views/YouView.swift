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
                    Text("Bedside · Beta")
                        .font(.bedsideMono(9))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Bedside.ink4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(Bedside.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .alert("Clear library?", isPresented: $confirmReset) {
                Button("Clear all", role: .destructive) { store.resetLibrary() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All books and favourites will be removed. This cannot be undone.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: "Profile")
            Text("You")
                .font(.bedsideDisplay(36))
                .kerning(-0.7)
                .foregroundStyle(Bedside.ink1)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(stats, id: \.label) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stat.value)")
                        .font(.bedsideDisplay(24))
                        .kerning(-0.5)
                        .foregroundStyle(Bedside.ink1)
                    MetaLabel(text: stat.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Bedside.paper1)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Bedside.paperEdge, lineWidth: 0.5)
                )
            }
        }
    }

    private var favoriteAuthors: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "Favorite authors · \(store.favoriteAuthors.count)")
            if store.favoriteAuthors.isEmpty {
                Text("Tap the heart next to an author's name on a book detail page.")
                    .font(.bedsideUI(12))
                    .foregroundStyle(Bedside.ink3)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(store.favoriteAuthors).sorted(), id: \.self) { name in
                        Button { store.toggleFavoriteAuthor(name) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Bedside.rust)
                                Text(name)
                            }
                            .font(.bedsideDisplay(13).italic())
                            .foregroundStyle(Bedside.ink1)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Bedside.paper1)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Bedside.paperEdge, lineWidth: 0.5))
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
            // Notifications / Export library are tracked in BACKLOG.md.
            // Kept out of TestFlight builds to avoid dead-end taps.
            appearanceRow
            settingsRow("Clear library", isLast: true) { confirmReset = true }
        }
    }

    /// Inline toggle for Light ↔ Dark. Persisted via BookStore so the choice
    /// survives relaunch; the SwiftUI scene reads `store.appearance` and
    /// applies `.preferredColorScheme` accordingly.
    private var appearanceRow: some View {
        Toggle(isOn: Binding(
            get: { store.appearance == .dark },
            set: { store.setAppearance($0 ? .dark : .light) }
        )) {
            HStack(spacing: 10) {
                Image(systemName: store.appearance == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Bedside.ink3)
                    .frame(width: 18)
                Text("Dark mode")
                    .font(.bedsideUI(15))
                    .foregroundStyle(Bedside.ink1)
            }
        }
        .tint(Bedside.sienna)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Bedside.paperEdge).frame(height: 0.5)
        }
        .accessibilityLabel("Dark mode")
        .accessibilityHint("Switches Bedside between the light Paperback Daylight palette and the dark Library at Night palette.")
    }

    private func settingsRow(_ label: String, isLast: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(label).font(.bedsideUI(15)).foregroundStyle(Bedside.ink1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Bedside.ink3)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Bedside.paperEdge).frame(height: 0.5) }
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
