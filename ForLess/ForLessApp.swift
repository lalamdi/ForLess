//
//  ForLessApp.swift
//  ForLess
//
//  Created by lama alemadi on 24/10/2026.
//

import SwiftUI
import FirebaseCore

@main
struct ForLessApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
