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
            .background(Folio.paper0.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Folio.ink2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Folio.sienna : Folio.ink4)
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
                            .font(.folioMono(9))
                            .tracking(0.7)
                    }
                    .foregroundStyle(Folio.ink3)
                    .frame(width: 80, height: 120)
                    .background(Folio.paper1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Folio.paperEdge, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    )
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                MetaLabel(text: "Cover photo")
                Text("Optional. Snap your copy — it'll be the cover in your library.")
                    .font(.folioUI(12))
                    .foregroundStyle(Folio.ink3)
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
                .font(display ? .folioDisplay(22) : .folioUI(15))
                .foregroundStyle(Folio.ink1)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Folio.paperEdge).frame(height: 0.5)
                }
        }
    }

    private func save() {
        let yearInt = Int(year.trimmingCharacters(in: .whitespaces))
        let id = store.addBook(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            year: yearInt,
            status: status,
            photoData: photoData
        )
        onSaved(id)
        dismiss()
    }
}
