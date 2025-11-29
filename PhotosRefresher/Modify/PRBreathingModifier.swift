//
//  BreathingModifier.swift
//  PhotosRefresher
//
//  Created by ty on 2025/11/22.
//

import SwiftUI

// MARK: - 呼吸效果 Modifier
struct PRBreathingModifier: ViewModifier {
    @State private var isAnimating = false
    
    let minScale: CGFloat
    let maxScale: CGFloat
    let minOpacity: Double
    let maxOpacity: Double
    let duration: Double
    
    init(
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        minOpacity: Double = 0.6,
        maxOpacity: Double = 1.0,
        duration: Double = 2.0
    ) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? maxScale : minScale)
            .opacity(isAnimating ? maxOpacity : minOpacity)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - View Extension
extension View {
    /// 添加呼吸效果
    /// - Parameters:
    ///   - minScale: 最小缩放比例，默认 0.95
    ///   - maxScale: 最大缩放比例，默认 1.05
    ///   - minOpacity: 最小透明度，默认 0.6
    ///   - maxOpacity: 最大透明度，默认 1.0
    ///   - duration: 动画时长（秒），默认 2.0
    func breathing(
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        minOpacity: Double = 0.6,
        maxOpacity: Double = 1.0,
        duration: Double = 2.0
    ) -> some View {
        self.modifier(
            PRBreathingModifier(
                minScale: minScale,
                maxScale: maxScale,
                minOpacity: minOpacity,
                maxOpacity: maxOpacity,
                duration: duration
            )
        )
    }
}
