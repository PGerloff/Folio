// AddBookSheet.swift — fast-add bottom sheet (shopping-list first)

import SwiftUI

struct AddBookSheet: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onAdded: (UUID) -> Void

    @State private var query = ""
    @State private var destination: BookStatus = .shopping
    @State private var showManual = false
    @State private var suggestions: [BookSuggestion] = []
    @State private var suggestionsLoading = true
    @State private var suggestionsFailed = false
    /// Increments each time a book is added from this sheet — drives the
    /// success haptic so it fires exactly once per add.
    @State private var addCounter = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    destinationPicker

                    quickEntry

                    methodGrid

                    VStack(alignment: .leading, spacing: 10) {
                        MetaLabel(text: "Popular right now")
                        if suggestionsLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(Bedside.ink3)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if suggestionsFailed {
                            Text("Couldn't load suggestions right now. Check your connection and try reopening.")
                                .font(.bedsideUI(13))
                                .foregroundStyle(Bedside.ink3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Bedside.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, suggestion in
                                    Button {
                                        let id = store.addBook(title: suggestion.title,
                                                               author: suggestion.author,
                                                               status: destination)
                                        addCounter += 1
                                        let theStore = store
                                        let title = suggestion.title
                                        let author = suggestion.author
                                        Task {
                                            await theStore.fetchCoverFromOpenLibrary(for: id,
                                                                                     title: title,
                                                                                     author: author)
                                        }
                                        onAdded(id)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(suggestion.title).font(.bedsideDisplay(15)).foregroundStyle(Bedside.ink1)
                                                Text(suggestion.author).font(.bedsideUI(12)).foregroundStyle(Bedside.ink3)
                                            }
                                            Spacer()
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Bedside.paper0)
                                                .frame(width: 28, height: 28)
                                                .background(Circle().fill(Bedside.sienna))
                                        }
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .top) {
                                        if idx == 0 { Rectangle().fill(Bedside.paperEdge).frame(height: 0.5) }
                                    }
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(Bedside.paperEdge).frame(height: 0.5)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .background(Bedside.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Bedside.ink2)
                }
            }
            .sheet(isPresented: $showManual) {
                ManualEntryView(initialStatus: destination, onSaved: onAdded)
            }
            .task { await loadSuggestions() }
            .sensoryFeedback(.impact(weight: .light), trigger: addCounter)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: "Quick add")
            Text("What's it called?")
                .font(.bedsideDisplay(26))
                .kerning(-0.5)
                .foregroundStyle(Bedside.ink1)
        }
        .padding(.top, 4)
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: "Add to")
            HStack(spacing: 4) {
                destButton(.shopping, label: "Shopping list", hint: "Want to buy")
                destButton(.toread,   label: "To Read",       hint: "Already own")
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Bedside.paper1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Bedside.paperEdge, lineWidth: 0.5)
                    )
            )
        }
    }

    private func destButton(_ status: BookStatus, label: String, hint: String) -> some View {
        let on = destination == status
        return Button { destination = status } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.bedsideUI(13, weight: .medium))
                Text(hint.uppercased())
                    .font(.bedsideMono(10))
                    .tracking(0.7)
                    .opacity(0.6)
            }
            .foregroundStyle(on ? Bedside.ink1 : Bedside.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(on ? Bedside.paper0 : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(on ? Bedside.paperEdge : .clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var quickEntry: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Bedside.ink3)
            TextField("Title, or \"Title by Author\"", text: $query)
                .font(.bedsideUI(14))
                .foregroundStyle(Bedside.ink1)
                .onSubmit { submit() }
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Add", action: submit)
                    .font(.bedsideUI(12, weight: .medium))
                    .foregroundStyle(Bedside.paper0)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Bedside.sienna))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Bedside.paper1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Bedside.paperEdge, lineWidth: 0.5)
                )
        )
    }

    private var methodGrid: some View {
        Button { showManual = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.system(size: 20))
                    .foregroundStyle(Bedside.sienna)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full details").font(.bedsideDisplay(14)).foregroundStyle(Bedside.ink1)
                    MetaLabel(text: "Title · author · year")
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Bedside.paper1)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Bedside.paperEdge, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        // Split on " by " for "Title by Author" entry.
        let parts = q.components(separatedBy: " by ")
        let title  = parts[0].trimmingCharacters(in: .whitespaces)
        let author = parts.count > 1 ? parts[1...].joined(separator: " by ").trimmingCharacters(in: .whitespaces) : "Unknown"
        let id = store.addBook(title: title, author: author, status: destination)
        addCounter += 1
        query = ""
        onAdded(id)
    }

    // MARK: - Open Library suggestions

    // Session-level cache — avoids re-fetching on every sheet open.
    // `@MainActor` because static mutable state is otherwise a Swift 6 data race;
    // all access is from SwiftUI view code which already runs on main.
    @MainActor private static var cachedSuggestions: [BookSuggestion] = []
    @MainActor private static var cacheDate: Date?
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    @MainActor
    private func loadSuggestions() async {
        if let date = Self.cacheDate,
           Date().timeIntervalSince(date) < Self.cacheTTL,
           !Self.cachedSuggestions.isEmpty {
            suggestions = Self.cachedSuggestions
            suggestionsLoading = false
            return
        }

        async let trending = fetchTrending(take: 3)
        async let classics = fetchClassics(take: 2)
        let (t, c) = await (trending, classics)
        let result = t + c
        if !result.isEmpty {
            Self.cachedSuggestions = result
            Self.cacheDate = Date()
            suggestionsFailed = false
        } else {
            // Both endpoints returned nothing — almost always a network/API
            // failure. Surface it instead of showing a blank section.
            suggestionsFailed = true
        }
        suggestions = result
        suggestionsLoading = false
    }

    private func fetchTrending(take: Int) async -> [BookSuggestion] {
        // Open Library's /trending/*.json endpoints return HTML, not JSON —
        // trending is a web-only feature. Use the search API with
        // sort=currently_reading, which surfaces the books people are
        // actively reading right now (the closest live "trending" signal).
        // If that returns nothing, fall back to readinglog (all-time
        // reading-list popularity).
        if let result = await popularBooks(sort: "currently_reading", take: take), !result.isEmpty {
            return result
        }
        return await popularBooks(sort: "readinglog", take: take) ?? []
    }

    private func popularBooks(sort: String, take: Int) async -> [BookSuggestion]? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            .init(name: "q",      value: "*:*"),
            .init(name: "sort",   value: sort),
            .init(name: "limit",  value: "\(take + 5)"),
            .init(name: "fields", value: "title,author_name")
        ]
        guard let url = components.url else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: OpenLibrary.request(url)) else { return nil }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        guard let decoded = try? JSONDecoder().decode(OLPopularResponse.self, from: data) else { return nil }
        let mapped: [BookSuggestion] = decoded.docs.compactMap { doc in
            guard let author = doc.author_name?.first else { return nil }
            return BookSuggestion(title: doc.title, author: author)
        }
        return Array(mapped.prefix(take))
    }

    private func fetchClassics(take: Int) async -> [BookSuggestion] {
        guard let url = URL(string: "https://openlibrary.org/subjects/classics.json?limit=30") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(for: OpenLibrary.request(url)) else { return [] }
        guard let response = try? JSONDecoder().decode(OLSubjectsResponse.self, from: data) else { return [] }
        return response.works.shuffled().prefix(take).compactMap { work in
            guard let author = work.authors?.first?.name else { return nil }
            return BookSuggestion(title: work.title, author: author)
        }
    }
}

// MARK: - Models

private struct BookSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let author: String
}

private struct OLPopularResponse: Decodable {
    struct Doc: Decodable {
        let title: String
        let author_name: [String]?
    }
    let docs: [Doc]
}

private struct OLSubjectsResponse: Decodable {
    struct Work: Decodable {
        struct Author: Decodable { let name: String }
        let title: String
        let authors: [Author]?
    }
    let works: [Work]
}
