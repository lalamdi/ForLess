//
//  CustomerTabView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//



//  Bottom tab bar of the customer side: Home, Orders and Profile.
//  The Profile screen can switch to the Orders tab (Order history row).
//

import SwiftUI

struct CustomerTabView: View {
    @State private var selection = 0                  // 0 Home, 1 Orders, 2 Profile
    @State private var chosenPlace: LocationOption?   // pickup place chosen on Home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(chosenPlace: $chosenPlace)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            OrdersView()
                .tabItem { Label("Orders", systemImage: "doc.text") }
                .tag(1)

            ProfileView(onSeeOrders: { selection = 1 })
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(2)
        }
        .tint(Color.brand)
    }
}
