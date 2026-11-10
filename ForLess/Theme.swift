//
//  Theme.swift
//  ForLess
//
//  Created by lama alemadi on 04/11/2026.
//

//Shared look of the app, taken from the Figma design:
//  brand colors, the orange button style, the labeled text field,
//  and the For Less logo drawn in code (price tag with a warm bowl).
//

import SwiftUI

// MARK: - Colors from the Figma design

extension Color {
    /// Creates a color from a hex number, e.g. Color(hex: 0xF26B21).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let brand = Color(hex: 0xF26B21)          // main orange (buttons, logo)
    static let brandDark = Color(hex: 0x9A3B0A)      // dark orange for headings on light orange
    static let brandText = Color(hex: 0xD2570F)      // orange for prices and links on white
    static let brandLight = Color(hex: 0xFFF0E6)     // light orange backgrounds
    static let ink = Color(hex: 0x14231B)            // main text color
    static let muted = Color(hex: 0x6B7A72)          // secondary text color
    static let appBackground = Color(hex: 0xF6F9F7)  // light grey screen background
    static let line = Color(hex: 0xE3EAE6)           // borders and dividers
}

// MARK: - Orange button

/// The full-width orange button used for main actions (Send code, Pay, etc.).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            // Slightly lighter while the button is being pressed
            .background(Color.brand.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Text field with a label above it

/// A white rounded input box with a small label on top (e.g. "Full name").
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content   // the TextField (or row) shown inside the box

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ink)
            content
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line))
        }
    }
}

// MARK: - For Less logo

/// The logo drawing: a price tag with a bowl and steam inside.
/// All shapes use a 120 x 120 grid and are scaled to the view's size.
struct LogoMark: View {
    var tagColor: Color = .white      // color of the tag
    var detailColor: Color = .brand   // color of the hole, bowl and steam

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 120   // scale from the 120 grid
            ZStack {
                TagShape().fill(tagColor)
                // Hole at the top corner of the tag
                Circle()
                    .fill(detailColor)
                    .frame(width: 12 * s, height: 12 * s)
                    .position(x: 84 * s, y: 36 * s)
                BowlShape().fill(detailColor)
                SteamShape().stroke(detailColor, style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The orange rounded-square app icon with the white logo inside.
struct AppIconView: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 28 / 120).fill(Color.brand)
            LogoMark()
        }
        .frame(width: size, height: size)
    }
}

/// Outline of the price tag (pointing to the bottom-left).
private struct TagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120
        // Converts a point on the 120 grid to a point in this view
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(62, 22))
        path.addLine(to: p(94, 22))
        path.addQuadCurve(to: p(98, 26), control: p(98, 22))         // rounded top-right corner
        path.addLine(to: p(98, 58))
        path.addLine(to: p(58, 98))
        path.addQuadCurve(to: p(51, 98), control: p(54.5, 101.5))   // rounded bottom tip
        path.addLine(to: p(22, 69))
        path.addQuadCurve(to: p(22, 62), control: p(18.5, 65.5))    // rounded left tip
        path.closeSubpath()
        return path
    }
}

/// Half-circle bowl in the middle of the tag.
private struct BowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 35 * s, y: rect.minY + 66 * s))
        path.addLine(to: CGPoint(x: rect.minX + 75 * s, y: rect.minY + 66 * s))
        // Draws the bottom half of a circle back to the start point
        path.addArc(center: CGPoint(x: rect.minX + 55 * s, y: rect.minY + 66 * s),
                    radius: 20 * s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// Three wavy steam lines above the bowl.
private struct SteamShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        for x: CGFloat in [46, 55, 64] {
            path.move(to: p(x, 59))
            path.addCurve(to: p(x, 48), control1: p(x - 3, 55), control2: p(x + 3, 53))
        }
        return path
    }
}

// MARK: - Keyboard

extension View {
    /// Tapping outside a text field closes the keyboard.
    func hideKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }
}
