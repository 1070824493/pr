//
//  MultiProgressBarView.swift

//
//  Created by ty on 2025/11/16.
//

import SwiftUI

struct MultiProgressBarView: View {
    
    var progressList: [Double]   // 0.0 ~ 1.0
    var progressColor: [Color] = [
        
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                Rectangle()
                    .fill(Color.hexColor(0xFF5A5A))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    
                
                ForEach(Array(progressList.reversed().enumerated()), id: \.offset) { index, progress in
                    // 进度条 - 使用动画修饰符实现平滑效果
                    Rectangle()
                        .fill(progressColor.reversed()[index])
                        .frame(width: geometry.size.width * CGFloat(progress), height: geometry.size.height)
//                        .cornerRadius(8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
//                        .zIndex(Double(index + 1))
                }
            }
            .cornerRadius(8)
        }
    }
}
