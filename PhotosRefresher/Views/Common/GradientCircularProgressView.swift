//
//  CircleProgressView.swift

//
//  Created by zyb on 2025/8/23.
//

import SwiftUI

struct GradientCircularProgressView: View {
    
    var progressList: [Double]   // 0.0 ~ 1.0
    var progressColor: [[Color]] = [
        [Color.hexColor(0xFFE9BE), Color.hexColor(0xFDA869)],
        [Color.hexColor(0x45F0F6), Color.hexColor(0x01C5E6)],
    ]
    var body: some View {
        ZStack {
            // 背景灰色圆环
            Circle()
                .stroke(lineWidth: 18)
                .frame(width: 180, height: 180, alignment: .center)
                .foregroundColor(Color.hexColor(0xA2C3D0).opacity(0.2))
            
            ForEach(Array(progressList.enumerated()), id: \.offset) { index, progress in
                // 前景进度环
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: progressColor[index]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90)) // 从顶部开始
                    .frame(width: 180, height: 180, alignment: .center)
                    .animation(.linear, value: progress)
            }
        }
        .frame(width: 180, height: 180)
    }
}


