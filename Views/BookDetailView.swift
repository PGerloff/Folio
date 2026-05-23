// BookDetailView.swift — single-book screen with photo, status, rating, notes

import SwiftUI

struct BookDetailView: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookId: UUID

    @State private var noteDraft = ""
    @State private var showDeleteAlert = false
    @State private var showShare = false

    private var book: Book? { store.book(bookId) }

    var body: some View {
        Group {
            if let book {
                content(book: book)
            } else {
                VStack {
                    Text("Book not found").foregroundStyle(.secondary)
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(book: Book) -> some View {
        ZStack(alignment: .top) {
            // Color wash behind the hero
            LinearGradient(
                colors: [
                    book.photoFilename != nil ? Color.black.opacity(0.55) : Bedside.coverColor(book.coverColor),
                    Bedside.paper0
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 340)
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    navRow(book: book)
                    coverHero(book: book)
                    titleBlock(book: book)
                    statusSection(book: book)
                    if book.status == .finished { ratingSection(book: book) }
                    notesSection(book: book)
                        .padding(.top, 28)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(Bedside.paper0.ignoresSafeArea())
        .sheet(isPresented: $showShare) {
            ShareSheetLoader(book: book, store: store)
        }
        .alert("Remove this book?", isPresented: $showDeleteAlert) {
            Button("Remove", role: .destructive) {
                store.remove(bookId)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the book from your library.")
        }
        // Haptic feedback on meaningful state changes
        .sensoryFeedback(.impact(weight: .light), trigger: book.isFavorite)
        .sensoryFeedback(.impact(weight: .light), trigger: book.rating)
        .sensoryFeedback(.success, trigger: book.status == .finished)
    }

    private func navRow(book: Book) -> some View {
        HStack {
            CircleIconButton(systemName: "chevron.left",
                             accessibilityLabel: "Back") { dismiss() }
            Spacer()
            CircleIconButton(systemName: book.isFavorite ? "heart.fill" : "heart",
                             tint: book.isFavorite ? Bedside.rust : Bedside.ink1,
                             accessibilityLabel: book.isFavorite ? "Remove from favourites" : "Add to favourites") {
                store.toggleFavorite(book.id)
            }
            CircleIconButton(systemName: "square.and.arrow.up",
                             accessibilityLabel: "Share book") {
                showShare = true
            }
            CircleIconButton(systemName: "trash",
                             accessibilityLabel: "Delete book") {
                showDeleteAlert = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func coverHero(book: Book) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CoverView(book, width: 150)
                .rotationEffect(book.photoFilename == nil ? .degrees(-1.5) : .zero)

            // Camera button overlay
            PhotoPickerButton(onPick: { data in store.setPhoto(book.id, data: data) }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Bedside.paper0)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Bedside.ink1))
                    .overlay(Circle().strokeBorder(Bedside.paper0, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
            }
            .offset(x: 10, y: 10)
        }
        .padding(.top, 18)
        .overlay(alignment: .topTrailing) {
            if book.photoFilename != nil {
                // remove-photo button positioned above the cover
                Button {
                    store.setPhoto(book.id, data: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Bedside.paper0)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Bedside.ink1.opacity(0.85)))
                        .overlay(Circle().strokeBorder(Bedside.paper0, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .offset(x: -90, y: 8) // hover near top-right of the 150-wide cover
            }
        }
    }

    private func titleBlock(book: Book) -> some View {
        VStack(spacing: 6) {
            Text(book.title)
                .font(.bedsideDisplay(28))
                .kerning(-0.5)
                .foregroundStyle(Bedside.ink1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 6) {
                Text("by ").foregroundStyle(Bedside.ink2) +
                Text(book.author).italic().foregroundStyle(Bedside.ink2)

                Button {
                    store.toggleFavoriteAuthor(book.author)
                } label: {
                    let isFav = store.favoriteAuthors.contains(book.author)
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 11))
                        .foregroundStyle(isFav ? Bedside.rust : Bedside.ink3)
                }
                .buttonStyle(.plain)
            }
            .font(.bedsideDisplay(14))

            if let year = book.year {
                MetaLabel(text: String(year))
                    .padding(.top, 4)
            }
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func statusSection(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: "Status")
            StatusPicker(status: Binding(
                get: { book.status },
                set: { store.setStatus(book.id, $0) }
            ))
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }

    @ViewBuilder
    private func ratingSection(book: Book) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                MetaLabel(text: "Your rating")
                StarsView(rating: book.rating, size: 18,
                          color: book.rating == nil ? Bedside.ink4 : Bedside.sienna) { newValue in
                    store.setRating(book.id, newValue)
                }
            }
            Spacer()
            if let date = book.finishedDate {
                MetaLabel(text: date)
            }
        }
        .bedsideCard()
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }

    @ViewBuilder
    private func notesSection(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "Notes · \(book.notes.count)")

            VStack(alignment: .trailing, spacing: 6) {
                TextField("A thought, a quote, a margin scribble…",
                          text: $noteDraft, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.bedsideUI(14))
                    .foregroundStyle(Bedside.ink1)
                    .padding(.bottom, 4)

                Button {
                    let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addNote(book.id, text: trimmed)
                    noteDraft = ""
                } label: {
                    Text("Add note")
                        .font(.bedsideUI(12, weight: .medium))
                        .foregroundStyle(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Bedside.ink3 : Bedside.paper0)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Bedside.paper2 : Bedside.sienna)
                        )
                }
                .buttonStyle(.plain)
                .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .bedsideCard(padding: 14)

            ForEach(book.notes) { note in
                HStack(alignment: .top, spacing: 12) {
                    Rectangle().fill(Bedside.sienna).frame(width: 2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.text)
                            .font(.bedsideUI(14))
                            .foregroundStyle(Bedside.ink1)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(note.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.bedsideMono(9))
                                .tracking(0.7)
                                .textCase(.uppercase)
                                .foregroundStyle(Bedside.ink4)
                            Spacer()
                            Button {
                                store.removeNote(book.id, noteId: note.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Bedside.ink4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.trailing, 14)
                }
                .background(Bedside.paper1)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Share loader

/// Resolves the share payload asynchronously then presents the system share sheet.
/// The `Color.clear` placeholder is invisible — UIActivityViewController draws
/// its own chrome on top as soon as `items` is populated (usually < 1 frame).
private struct ShareSheetLoader: View {
    let book: Book
    let store: BookStore
    @State private var items: [Any]?

    var body: some View {
        Group {
            if let items {
                ShareSheet(activityItems: items)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .task {
            let text = BookShareContent.text(for: book)
            let image = await BookShareContent.coverImage(for: book, store: store)
            var result: [Any] = [text]
            if let image { result.append(image) }
            items = result
        }
    }
}

// MARK: - Helper

private struct CircleIconButton: View {
    let systemName: String
    var tint: Color = Bedside.ink1
    var background: Color? = nil
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(background ?? Bedside.paper0.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
