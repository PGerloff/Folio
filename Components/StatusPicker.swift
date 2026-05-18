// StatusPicker.swift — segmented control for the four primary statuses

import SwiftUI

struct StatusPicker: View {
    @Binding var status: BookStatus
    var options: [BookStatus] = BookStatus.pickable

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { opt in
                Button {
                    status = opt
                } label: {
                    Text(opt.label)
                        .font(.folioUI(12, weight: .medium))
                        .foregroundStyle(status == opt ? Folio.ink1 : Folio.ink3)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(status == opt ? Folio.paper0 : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(status == opt ? Folio.paperEdge : .clear, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Folio.paper1)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Folio.paperEdge, lineWidth: 0.5)
                )
        )
    }
}
