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
        // `.task(id:)` auto-cancels the previous task when `pickerItem` changes,
        // so rapid successive selections can't race each other. Runs on the
        // view's MainActor by default, making @State writes safe.
        .task(id: pickerItem) {
            guard let item = pickerItem else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                onPick(data)
            }
            pickerItem = nil
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
            picker.dismiss(animated: true)
            onResult(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // UIKit convention: delegate must dismiss the picker.
            // Without this, the camera UI freezes for a frame on Cancel.
            picker.dismiss(animated: true)
            onResult(nil)
        }
    }
}
