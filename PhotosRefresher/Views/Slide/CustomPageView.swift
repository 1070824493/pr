//
//  CustomPageView.swift
//  PhotosRefresher
//
//  Created by ty on 2025/11/22.
//

import SwiftUI
import Photos

// 自定义 TabView 容器
struct CustomPageView: View {
    @Binding var index: Int
    let assets: [PHAsset]
    var pushToTrash: (PHAsset) -> Void
    var openTrashReview: () -> Void
    var onDragUpdate: (Bool, Double) -> Void
    
    @State private var currentAxisLock: ZoomInteractiveCard.AxisLock = .none
    @State private var pageAxisLock: ZoomInteractiveCard.AxisLock = .none
    @GestureState private var gestureOffset: CGFloat = 0
    @GestureState private var isGestureDragging: Bool = false
    @State private var preloadedIndices: Set<Int> = []
    
    var body: some View {
        GeometryReader { geo in
            let width = kScreenWidth - 30
            let size = CGSize(width: width, height: geo.size.height * 0.82)
            
            HStack(spacing: 0) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { i, asset in
                    ZoomInteractiveCard(
                        asset: asset,
                        onDelete: { pushToTrash(asset) },
                        onDragUpdate: onDragUpdate,
                        onAxisLockChange: { lock in
                            currentAxisLock = lock
                        },
                        isPageDragging: pageAxisLock == .horizontal
                    )
                    .frame(width: geo.size.width)
                }
            }
            .offset(x: -CGFloat(index) * geo.size.width + gestureOffset)
            .contentShape(Rectangle())  // 确保整个内容区域可以响应手势
            .simultaneousGesture( 
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 如果卡片已经锁定为垂直，不处理页面手势
                        if currentAxisLock == .vertical { return }
                        
                        // 确定页面级别的轴锁定
                        if pageAxisLock == .none {
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            if dx > dy + 8 {
                                pageAxisLock = .horizontal
                            } else if dy > dx + 8 {
                                pageAxisLock = .vertical
                            }
                        }
                    }
                    .updating($gestureOffset) { value, state, _ in
                        // 只有在页面锁定为水平时才更新偏移
                        if pageAxisLock == .horizontal {
                            state = value.translation.width
                        }
                    }
                    .updating($isGestureDragging) { _, state, _ in
                        if pageAxisLock == .horizontal {
                            state = true
                        }
                    }
                    .onEnded { value in
                        // 只在水平锁定时处理分页
                        if pageAxisLock == .horizontal {
                            let threshold: CGFloat = 50
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if value.translation.width < -threshold || velocity < -100 {
                                    // 向左滑
                                    if index < assets.count - 1 {
                                        index += 1
                                    } else {
                                        // 最后一页继续左滑，打开垃圾箱
                                        if value.translation.width < -threshold {
                                            openTrashReview()
                                        }
                                    }
                                } else if value.translation.width > threshold || velocity > 100 {
                                    // 向右滑
                                    if index > 0 {
                                        index -= 1
                                    }
                                }
                            }
                        }
                        // 重置页面轴锁定
                        pageAxisLock = .none
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
            .onAppear {
                preloadAdjacentImages(currentIndex: index, size: size)
            }
            .onChange(of: index) { newIndex in
                preloadAdjacentImages(currentIndex: newIndex, size: size)
            }
        }
        .clipped()  // 裁剪内容，确保不影响外部区域
    }
    
    // 预加载相邻图片的方法
    private func preloadAdjacentImages(currentIndex: Int, size: CGSize) {
        let indicesToPreload = [
            currentIndex - 1,  // 前一张
            currentIndex,      // 当前
            currentIndex + 1   // 后一张
        ].filter { $0 >= 0 && $0 < assets.count }
        
        let provider = PRAssetThumbnailProvider()
        
        for index in indicesToPreload {
            // 避免重复预加载
            if !preloadedIndices.contains(index) {
                let asset = assets[index]
                
                // 异步预加载
                DispatchQueue.global(qos: .userInitiated).async {
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    options.isSynchronous = false
                    
                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: size,
                        contentMode: .aspectFill,
                        options: options
                    ) { _, _ in
                        DispatchQueue.main.async {
                            preloadedIndices.insert(index)
                        }
                    }
                }
            }
        }
        
        // 清理远离当前页面的缓存（保持内存使用合理）
        let indicesToKeep = Set([
            currentIndex - 2,
            currentIndex - 1,
            currentIndex,
            currentIndex + 1,
            currentIndex + 2
        ].filter { $0 >= 0 && $0 < assets.count })
        
        preloadedIndices = preloadedIndices.intersection(indicesToKeep)
    }
}
