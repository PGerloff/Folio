// ManualEntryView.swift — full form with photo capture

import SwiftUI

struct ManualEntryView: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var initialStatus: BookStatus = .shopping
    let onSaved: (UUID) -> Void

    @State private var title = ""
    @State private var author = ""
    @State private var year = ""
    @State private var status: BookStatus = .shopping
    @State private var photoData: Data?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    coverRow

                    field(label: "TITLE",  text: $title,  display: true)
                    field(label: "AUTHOR", text: $author)
                    field(label: "YEAR",   text: $year,   keyboard: .numberPad)

                    VStack(alignment: .leading, spacing: 8) {
                        MetaLabel(text: "Add to")
                        StatusPicker(status: $status)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(Bedside.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Bedside.ink2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Bedside.sienna : Bedside.ink4)
                        .disabled(!canSave)
                }
            }
            .onAppear { status = initialStatus }
        }
    }

    private var coverRow: some View {
        HStack(alignment: .center, spacing: 14) {
            if let data = photoData, let ui = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    Button { photoData = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.black.opacity(0.65)))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            } else {
                PhotoPickerButton(onPick: { data in photoData = data }) {
                    VStack(spacing: 4) {
                        Image(systemName: "camera").font(.system(size: 20))
                        Text("PHOTO")
                            .font(.bedsideMono(9))
                            .tracking(0.7)
                    }
                    .foregroundStyle(Bedside.ink3)
                    .frame(width: 80, height: 120)
                    .background(Bedside.paper1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Bedside.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    )
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                MetaLabel(text: "Cover photo")
                Text("Optional. Snap your copy — it'll be the cover in your library.")
                    .font(.bedsideUI(12))
                    .foregroundStyle(Bedside.ink3)
            }
        }
        .padding(.bottom, 6)
    }

    private func field(label: String, text: Binding<String>, display: Bool = false,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(text: label)
            TextField("", text: text)
                .keyboardType(keyboard)
                .font(display ? .bedsideDisplay(22) : .bedsideUI(15))
                .foregroundStyle(Bedside.ink1)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Bedside.paperEdge).frame(height: 0.5)
                }
        }
    }

    private func save() {
        let yearInt = Int(year.trimmingCharacters(in: .whitespaces))
        let trimmedTitle  = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = store.addBook(
            title: trimmedTitle,
            author: trimmedAuthor,
            year: yearInt,
            status: status,
            photoData: photoData
        )
        // If the user didn't supply a photo and we have both title + author,
        // try to source a cover from Open Library in the background.
        if photoData == nil, !trimmedTitle.isEmpty, !trimmedAuthor.isEmpty {
            let theStore = store
            Task {
                await theStore.fetchCoverFromOpenLibrary(for: id,
                                                        title: trimmedTitle,
                                                        author: trimmedAuthor)
            }
        }
        onSaved(id)
        dismiss()
    }
}
