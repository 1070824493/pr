//
//  ProgressBarView.swift

//
//  Created by ty on 2025/11/16.
//

import SwiftUI

struct ProgressBarView: View {
    
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                Rectangle()
                    .fill(Color.hexColor(0x141414).opacity(0.06))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .cornerRadius(4)
                
                // 进度条 - 使用动画修饰符实现平滑效果
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(progress), height: geometry.size.height)
                    .cornerRadius(4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
    }
}
