//
//  CustomerTabView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Bottom tab bar of the customer side: Home, Orders and Profile.
//  Orders and Profile are placeholders until those screens are built.
//
 
import SwiftUI
 
struct CustomerTabView: View {
    @State private var selection = 0   // 0 Home, 1 Orders, 2 Profile
 
    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
 
            placeholder("Orders")
                .tabItem { Label("Orders", systemImage: "doc.text") }
                .tag(1)
 
            placeholder("Profile")
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(2)
        }
        .tint(Color.brand)   // orange selected tab
    }
 
    /// Temporary screen for tabs that are not built yet.
    private func placeholder(_ title: String) -> some View {
        NavigationStack {
            Text("\(title) is coming soon")
                .foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                .navigationTitle(title)
        }
    }
}
