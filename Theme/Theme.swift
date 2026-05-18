// Theme.swift — Folio palette + typography

import SwiftUI

// MARK: - Hex helper

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8)  & 0xff) / 255
        let b = Double( hex        & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Palette

enum Folio {
    // Paper
    static let paper0    = Color(hex: 0xF5ECD8)
    static let paper1    = Color(hex: 0xEFE4CB)
    static let paper2    = Color(hex: 0xE6D8B8)
    static let paperEdge = Color(hex: 0xD4C194)

    // Ink
    static let ink1 = Color(hex: 0x221911)
    static let ink2 = Color(hex: 0x4A3B2A)
    static let ink3 = Color(hex: 0x806B4F)
    static let ink4 = Color(hex: 0xB09572)

    // Accents
    static let sienna     = Color(hex: 0xB05328)
    static let siennaSoft = Color(hex: 0xC77B53)
    static let sage       = Color(hex: 0x6E7A4A)
    static let rust       = Color(hex: 0x8E3A1A)
    static let moss       = Color(hex: 0x4F5733)

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
    static func folioDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// UI sans (SF Pro).
    static func folioUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Small-caps metadata (SF Mono).
    static func folioMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Reusable text styles

struct MetaLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.folioMono(10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(Folio.ink3)
    }
}

// MARK: - Shared modifiers

extension View {
    /// Inset card on paper-1 with hairline edge.
    func folioCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Folio.paper1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
            )
    }
}
