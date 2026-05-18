// PhotoPickerButton.swift — single button that lets the user pick a camera shot
// or a library photo, and returns the image data via `onPick`.

import SwiftUI
import PhotosUI
import UIKit

struct PhotoPickerButton<Label: View>: View {
    let onPick: (Data) -> Void
    @ViewBuilder var label: () -> Label

    @State private var showSourceChoice = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false

    var body: some View {
        Button {
            showSourceChoice = true
        } label: { label() }
        .buttonStyle(.plain)
        .confirmationDialog("Add a cover photo",
                            isPresented: $showSourceChoice,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showCamera) {
            CameraSheet { data in
                if let data { onPick(data) }
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { onPick(data) }
                }
                pickerItem = nil
            }
        }
    }
}

// MARK: - Camera sheet (UIImagePickerController wrapper)

private struct CameraSheet: UIViewControllerRepresentable {
    let onResult: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onResult: (Data?) -> Void
        init(onResult: @escaping (Data?) -> Void) { self.onResult = onResult }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            let data = image?.jpegData(compressionQuality: 0.9)
            onResult(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onResult(nil)
        }
    }
}
