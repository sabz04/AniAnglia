//
//  YukimoFlowLayout.swift
//  Custom Layout that wraps its subviews to multiple lines like a
//  hashtag cloud. Use for genre chips / filter chips etc.
//

import SwiftUI

struct YukimoFlowLayout: Layout {
    var hSpacing: CGFloat = 6
    var vSpacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(subviews: subviews, in: maxWidth)
        let height = rows.reduce(0) { acc, row in
            acc + row.maxHeight
        } + CGFloat(max(rows.count - 1, 0)) * vSpacing
        let width = min(rows.map(\.width).max() ?? 0, maxWidth)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let rows = computeRows(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = sizes(subviews)[index]
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x += size.width + hSpacing
            }
            y += row.maxHeight + vSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var maxHeight: CGFloat = 0
    }

    private func computeRows(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        let sizes = sizes(subviews)
        var rows: [Row] = [Row()]
        for (index, size) in sizes.enumerated() {
            var current = rows[rows.count - 1]
            let widthIfAdded = current.width + size.width + (current.indices.isEmpty ? 0 : hSpacing)
            if widthIfAdded > maxWidth, !current.indices.isEmpty {
                rows.append(Row(indices: [index],
                                width: size.width,
                                maxHeight: size.height))
            } else {
                current.indices.append(index)
                current.width = widthIfAdded
                current.maxHeight = max(current.maxHeight, size.height)
                rows[rows.count - 1] = current
            }
        }
        return rows
    }

    private func sizes(_ subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }
}
