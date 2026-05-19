// ShareSheet.swift — UIActivityViewController wrapper for SwiftUI

import SwiftUI
import UIKit

/// Presents the native iOS share sheet (UIActivityViewController) as a SwiftUI sheet.
/// Accepts any mix of shareable items — typically a String recommendation text
/// and an optional UIImage cover.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
