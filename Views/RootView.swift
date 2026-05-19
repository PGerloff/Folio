// RootView.swift — bottom tab bar shell

import SwiftUI

enum Tab: Hashable { case home, shop, library, you }

struct RootView: View {
    @State private var tab: Tab = .home
    @State private var showAdd = false
    @State private var pendingDetail: UUID?

    var body: some View {
        TabView(selection: $tab) {
            HomeView(showAdd: $showAdd, openBook: openBook, switchTo: { tab = $0 })
                .tabItem { Label("Home", systemImage: "book") }
                .tag(Tab.home)

            ShopView(showAdd: $showAdd, openBook: openBook)
                .tabItem { Label("Add", systemImage: "plus") }
                .tag(Tab.shop)

            LibraryView(openBook: openBook)
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)

            YouView(openBook: openBook)
                .tabItem { Label("You", systemImage: "person") }
                .tag(Tab.you)
        }
        .tint(Folio.sienna)
        .sheet(isPresented: $showAdd) {
            AddBookSheet(onAdded: { id in
                showAdd = false
                openBook(id)
            })
        }
        .sheet(item: Binding(
            get: { pendingDetail.map { BookID(id: $0) } },
            set: { pendingDetail = $0?.id }
        )) { wrap in
            BookDetailView(bookId: wrap.id)
        }
    }

    private func openBook(_ id: UUID) {
        pendingDetail = id
    }
}

/// Hashable wrapper so a UUID can drive `.sheet(item:)`.
private struct BookID: Identifiable, Hashable { let id: UUID }
