//
//  SplashView.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//  The orange start screen with the logo, shown for 2 seconds when the app opens.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            // Orange background that fills the whole screen
            Color.brand.ignoresSafeArea()

            VStack(spacing: 18) {
                // White price-tag logo with orange details
                LogoMark(tagColor: .white, detailColor: .brand)
                    .frame(width: 170, height: 170)
                Text("For Less")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Good food, less waste")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
