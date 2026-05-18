// AddBookSheet.swift — fast-add bottom sheet (shopping-list first)

import SwiftUI

struct AddBookSheet: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onAdded: (UUID) -> Void

    @State private var query = ""
    @State private var destination: BookStatus = .shopping
    @State private var showManual = false

    private let suggestions: [(String, String)] = [
        ("Klara and the Sun", "Kazuo Ishiguro"),
        ("The Bee Sting",     "Paul Murray"),
        ("Trust",             "Hernan Diaz"),
        ("Stoner",            "John Williams"),
    ]

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
                        VStack(spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, item in
                                Button {
                                    let id = store.addBook(title: item.0, author: item.1, status: destination)
                                    onAdded(id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.0).font(.folioDisplay(15)).foregroundStyle(Folio.ink1)
                                            Text(item.1).font(.folioUI(12)).foregroundStyle(Folio.ink3)
                                        }
                                        Spacer()
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Folio.paper0)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Folio.sienna))
                                    }
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .top) {
                                    if idx == 0 { Rectangle().fill(Folio.paperEdge).frame(height: 0.5) }
                                }
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(Folio.paperEdge).frame(height: 0.5)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .background(Folio.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Folio.ink2)
                }
            }
            .sheet(isPresented: $showManual) {
                ManualEntryView(initialStatus: destination, onSaved: onAdded)
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: "Quick add")
            Text("What's it called?")
                .font(.folioDisplay(26))
                .kerning(-0.5)
                .foregroundStyle(Folio.ink1)
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
                    .fill(Folio.paper1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
                    )
            )
        }
    }

    private func destButton(_ status: BookStatus, label: String, hint: String) -> some View {
        let on = destination == status
        return Button { destination = status } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.folioUI(13, weight: .medium))
                Text(hint.uppercased())
                    .font(.folioMono(10))
                    .tracking(0.7)
                    .opacity(0.6)
            }
            .foregroundStyle(on ? Folio.ink1 : Folio.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(on ? Folio.paper0 : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(on ? Folio.paperEdge : .clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var quickEntry: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Folio.ink3)
            TextField("Title, or \"Title by Author\"", text: $query)
                .font(.folioUI(14))
                .foregroundStyle(Folio.ink1)
                .onSubmit { submit() }
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Add", action: submit)
                    .font(.folioUI(12, weight: .medium))
                    .foregroundStyle(Folio.paper0)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Folio.sienna))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Folio.paper1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
                )
        )
    }

    private var methodGrid: some View {
        Button { showManual = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.system(size: 20))
                    .foregroundStyle(Folio.sienna)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full details").font(.folioDisplay(14)).foregroundStyle(Folio.ink1)
                    MetaLabel(text: "Title · author · year")
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Folio.paper1)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
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
        query = ""
        onAdded(id)
    }
}
