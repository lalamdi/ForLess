//
//  ForLessApp.swift
//  ForLess
//
//  Created by lama alemadi on 24/10/2026.
//

//  Entry point of the app. Firebase is started in AppDelegate,
//  and RootView decides which screen to show first.
//

import SwiftUI

@main
struct ForLessApp: App {
    // Connects AppDelegate so Firebase starts when the app launches
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)   // the design is light only, so typed text stays dark
        }
    }
}
