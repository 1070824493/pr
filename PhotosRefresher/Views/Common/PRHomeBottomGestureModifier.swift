//
//  HomeBottomGestureModifier.swift

//
//  
//

import SwiftUI


/// 给view添加底部Home手势拦截(仅全屏view生效)
struct PRHomeBottomGestureModifier: ViewModifier {
    
    let onShowingOverlay: (Bool) -> Void
    
    @State private var showingOveraly = false {
        didSet{
            onShowingOverlay(showingOveraly)
        }
    }
    @State private var swipeStartY: CGFloat? = nil
    private let bottomAreaHeight: CGFloat = 40
    private let swipeThreshold: CGFloat = 50
    
    func body(content: Content) -> some View {
        content
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                handleSwipeChange(value)
            }
            .onEnded { _ in
                handleSwipeEnd()
        })
        .defersSystemGestures(on: .bottom)
            
    }
    
    private func handleSwipeChange(_ value: DragGesture.Value) {
        
        guard !showingOveraly else {
            return
        }
        
        
        let currentY = value.location.y
        let screenHeight = UIScreen.main.bounds.height
        
        if swipeStartY == nil {
            let isBottomStart = value.startLocation.y >= screenHeight - bottomAreaHeight
            if isBottomStart {
                swipeStartY = value.startLocation.y
            }
            return
        }
        
        guard let startY = swipeStartY else { return }
        let swipeDistance = startY - currentY
        
        if swipeDistance >= swipeThreshold && !showingOveraly {
            showingOveraly = true
        }
    }
        
    private func handleSwipeEnd() {
        swipeStartY = nil
        showingOveraly = false
    }
}

extension View {
    public func onHomeBottomGestureSwipe(showingOverlay: @escaping (Bool) -> Void) -> some View {
        self.modifier(
            PRHomeBottomGestureModifier(onShowingOverlay: showingOverlay)
        )
    }
}


