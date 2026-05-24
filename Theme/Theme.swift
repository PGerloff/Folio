// Theme.swift — Bedside palette + typography

import SwiftUI
import UIKit

// MARK: - Hex helpers

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8)  & 0xff) / 255
        let b = Double( hex        & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xff) / 255
        let g = CGFloat((hex >> 8)  & 0xff) / 255
        let b = CGFloat( hex        & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

/// Builds a `Color` whose underlying UIColor resolves to `light` or `dark`
/// depending on the active trait collection. Lets SwiftUI pick the right
/// shade automatically when the system or user-controlled appearance flips.
private func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: dark)
            : UIColor(hex: light)
    })
}

// MARK: - Palette
//
// Two palettes coexist:
//
// • **Light (Paperback Daylight)** — the original aged-paper aesthetic.
// • **Dark (Library at Night)** — warm mahogany/leather; for low-light reading.
//
// Each token resolves dynamically via `UITraitCollection.userInterfaceStyle`,
// so views don't need to branch on color scheme — just keep using `Bedside.*`
// and the right shade comes through.

enum Bedside {
    // Paper — backgrounds & cards
    static let paper0    = dynamic(light: 0xF5ECD8, dark: 0x1C140C) // base background
    static let paper1    = dynamic(light: 0xEFE4CB, dark: 0x261B11) // card / chip surface
    static let paper2    = dynamic(light: 0xE6D8B8, dark: 0x2E2117) // raised chip / disabled
    static let paperEdge = dynamic(light: 0xD4C194, dark: 0x3A2A1B) // hairline strokes

    // Ink — text levels
    static let ink1 = dynamic(light: 0x221911, dark: 0xF1E5CC) // primary
    static let ink2 = dynamic(light: 0x4A3B2A, dark: 0xC9B58C) // secondary
    static let ink3 = dynamic(light: 0x806B4F, dark: 0x8E7A55) // meta labels
    static let ink4 = dynamic(light: 0xB09572, dark: 0x5E4E34) // whisper / placeholder

    // Accents
    static let sienna     = dynamic(light: 0xB05328, dark: 0xC46A3F)
    static let siennaSoft = dynamic(light: 0xC77B53, dark: 0xD89072)
    static let sage       = dynamic(light: 0x6E7A4A, dark: 0x9CA478)
    static let rust       = dynamic(light: 0x8E3A1A, dark: 0xB85A38)
    static let moss       = dynamic(light: 0x4F5733, dark: 0x8B9460)

    /// Cover-spine swatches. Intentionally identical in light + dark — they're
    /// meant to evoke real book spines, which look fine on either background.
    static func coverColor(_ c: CoverColor) -> Color {
        switch c {
        case .clay:  return Color(hex: 0xB4663D)
        case .ochre: return Color(hex: 0xC99649)
        case .rust:  return Color(hex: 0x8E3A1A)
        case .olive: return Color(hex: 0x6E7034)
        case .cocoa: return Color(hex: 0x4A3422)
        case .sand:  return Color(hex: 0xC8A571)
        case .sage:  return Color(hex: 0x828A5E)
        case .plum:  return Color(hex: 0x5C3535)
        case .tea:   return Color(hex: 0x9B8C5A)
        case .bone:  return Color(hex: 0xE6D6B0)
        }
    }

    static func statusDot(_ s: BookStatus) -> Color {
        switch s {
        case .reading:  return sage
        case .finished: return moss
        case .dnf:      return ink3.opacity(0.5)
        case .shopping, .toread: return sienna
        }
    }
}

// MARK: - Typography

extension Font {
    /// Display serif (New York on iOS) — closest system match to Newsreader.
    static func bedsideDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// UI sans (SF Pro).
    static func bedsideUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Small-caps metadata (SF Mono).
    static func bedsideMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Reusable text styles

struct MetaLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.bedsideMono(10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(Bedside.ink3)
    }
}

// MARK: - Shared modifiers

extension View {
    /// Inset card on paper-1 with hairline edge.
    func bedsideCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Bedside.paper1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Bedside.paperEdge, lineWidth: 0.5)
            )
    }
}
