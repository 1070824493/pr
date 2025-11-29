//
//  ScanAnimationModifier.swift
//  LandscapeAI
//
//  Created by zyb on 2025/9/4.
//

import Foundation
import SwiftUI

struct PRScanAnimationModifier: ViewModifier {
    private let cycle: Double = 4.5
    private let imageWidth: CGFloat = 30
    
    let clipRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    let width = proxy.size.width
                    TimelineView(.animation) { timeline in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let progress = now.truncatingRemainder(dividingBy: cycle)
                        let imageX = imageOffset(progress, in: width)
                        
                        ZStack {
                            // 固定图片
                            if let imageX {
                                Image("scan_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: proxy.size.height)
                                    .position(x: imageX, y: proxy.size.height / 2) // 在 content 内
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: clipRadius))
                    }
                }
            )
    }
    
    private func imageOffset(_ t: Double, in width: CGFloat) -> CGFloat? {
        
        let startX = 0.0              // 图片完整进入左边缘
        let endX = width
        
        switch t {
        case 1.5...2.5: // 第一次移动
            return lerp(startX, endX, (t - 1.5) / 1.0)
        case 3.0...4.0: // 第二次移动
            return lerp(startX, endX, (t - 3.0) / 1.0)
        default:
            return nil
        }
    }
    
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ progress: Double) -> CGFloat {
        a + (b - a) * CGFloat(progress)
    }
}

extension View {
    func withScanAnimation(clipRadius: CGFloat = 14.fit) -> some View {
        self.modifier(PRScanAnimationModifier(clipRadius: clipRadius))
    }
}
