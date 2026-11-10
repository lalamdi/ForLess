//
//  BusinessTabView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 06/11/2026.
//


//  Bottom tab bar of the business side:
//  Dashboard, Orders (BusinessOrdersView), Add deal (AddDealView)
//  and Profile (BusinessProfileView).
//
 

import SwiftUI
 
struct BusinessTabView: View {
    @State private var selection = 0   // 0 = Dashboard, 1 = Orders, 2 = Add deal, 3 = Profile
 
    var body: some View {
        TabView(selection: $selection) {
            // The buttons inside the dashboard can switch to the other tabs
            DashboardView(onAddDeal: { selection = 2 }, onSeeOrders: { selection = 1 })
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(0)
 
            BusinessOrdersView()
                .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
                .tag(1)
 
            AddDealView()
                .tabItem { Label("Add deal", systemImage: "plus") }
                .tag(2)

            BusinessProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(3)
        }
        .tint(Color.brand)   // orange selected tab
    }
}
