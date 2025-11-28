//
//  BlurView.swift

//
//

import SwiftUI

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .light

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return blur
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
