// BedsideApp.swift — application entry point

import SwiftUI

@main
struct BedsideApp: App {
    @State private var store = BookStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                // Honour the user-selected appearance from BookStore.
                // Defaults to `.light` (Paperback Daylight); the user can opt
                // in to `.dark` (Library at Night) from You → Settings.
                .preferredColorScheme(store.appearance == .dark ? .dark : .light)
        }
    }
}
