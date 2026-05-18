// FolioApp.swift — application entry point

import SwiftUI

@main
struct FolioApp: App {
    @State private var store = BookStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
