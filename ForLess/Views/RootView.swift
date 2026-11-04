//
//  RootView.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  Decides which screen to show:
//  splash (2 seconds) -> sign in, or home if the user is already signed in.
//

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @StateObject private var auth = AuthManager()   // shared with all screens below
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if auth.isSignedIn {
                ContentView()   // home screen (deals list for now)
            } else {
                SignInView()
            }
        }
        .environmentObject(auth)
        .task {
            // Show the splash for 2 seconds, then fade to the next screen
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSplash = false }
        }
        .onOpenURL { url in
            // Lets Firebase finish phone sign-in if it opened a web check (reCAPTCHA)
            _ = Auth.auth().canHandle(url)
        }
    }
}
