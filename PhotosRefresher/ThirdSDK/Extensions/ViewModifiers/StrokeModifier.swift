//
//  StrokeModifier.swift
//  Pods
//
//  View描边
//

//

import SwiftUI

struct StrokeModifier: ViewModifier {
    let id = UUID()
    var strokeSize: CGFloat = 1
    var strokeColor: Color = .blue
    var filter: GraphicsContext.Filter = .alphaThreshold(min: 0.01)

    func body(content: Content) -> some View {
        content
            .padding(strokeSize)
            .background(
                Rectangle()
                    .foregroundStyle(strokeColor)
                    .mask(outline(context: content))
            )
    }

    private func outline(context: Content) -> some View {
        Canvas { context, size in
            context.addFilter(filter)
            context.drawLayer { layer in
                if let text = context.resolveSymbol(id: id) {
                    layer.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                }
            }
        } symbols: {
            context.tag(id).blur(radius: strokeSize)
        }
    }
}
