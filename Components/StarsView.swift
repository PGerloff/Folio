// StarsView.swift — 1-5 star rating (read-only or interactive)

import SwiftUI

struct StarsView: View {
    let rating: Int        // 0…of
    let of: Int            // total stars (typically 5)
    let size: CGFloat
    let color: Color
    /// If set, tapping a star calls this with the new rating (1…of).
    /// Tapping the currently-set rating clears it to nil.
    var onChange: ((Int?) -> Void)?

    init(rating: Int?, of: Int = 5, size: CGFloat = 12, color: Color = Folio.ink2,
         onChange: ((Int?) -> Void)? = nil) {
        self.rating = rating ?? 0
        self.of = of
        self.size = size
        self.color = color
        self.onChange = onChange
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<of, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(color)
                    .padding(onChange != nil ? 3 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let cb = onChange else { return }
                        let next = i + 1
                        cb(rating == next ? nil : next)
                    }
            }
        }
    }
}
