//
//  BottomSheet.swift

//
//

import SwiftUI

struct PRBottomSheetView: View {
    @Binding var destination: AppBottomSheetDestination?
    
    @State private var currentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var isShowing: Bool = false
    
    private var hasMask: Bool {
        destination?.hasMask ?? true
    }
    
    private var dismissOnTapOutside: Bool {
        destination?.dismissOnTapOutside ?? true
    }
    
    private var draggable: Bool {
        destination?.draggable ?? true
    }
    
    private var maxHeight: CGFloat {
        let value = destination?.maxHeight ?? .infinity
        return value == .infinity ? .infinity : CGFloat(value)
    }
    
    private var effectiveMaxHeight: CGFloat {
        if maxHeight.isInfinite {
            return kScreenHeight - getStatusBarHeight()
        } else {
            return min(maxHeight, kScreenHeight - getStatusBarHeight())
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if isShowing {
                maskView
                    .ignoresSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        if dismissOnTapOutside {
                            dismiss()
                        }
                    }
            }
            
            ZStack {
                if isShowing {
                    sheetContent
                        .transition(
                           .asymmetric(
                               insertion: .move(edge: .bottom),
                               removal: .move(edge: .bottom)
                           )
                        )
                }
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .animation(.sheetAnimation, value: isShowing)
        .onAppear {
            isShowing = true
        }
    }
    
    private var maskView: some View {
        if hasMask {
            Color.black.opacity(0.8)
                .contentShape(Rectangle())
        } else {
            Color.clear
                .contentShape(Rectangle())
        }
    }
    
    private var sheetContent: some View {
        VStack(spacing: 0) {
//            dragIndicator
            
            if contentHeight > effectiveMaxHeight {
                ScrollView(showsIndicators: false) {
                    contentView
                }
                .frame(maxHeight: effectiveMaxHeight)
            } else {
                contentView
            }
        }
        .background(Color.white)
        .cornerRadius(fitScale(16), corners: [.topLeft, .topRight])
        .offset(y: currentOffset)
        .gesture(dragGesture)
    }
    
    private var contentView: some View {
        destination?.makeContentView()
            .readSize { size in
                contentHeight = size.height
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !draggable {
                    return
                }
                
                let translation = value.translation.height
                guard translation > 0 else { return }
                currentOffset = translation
            }
            .onEnded { value in
                if !draggable {
                    return
                }
                
                let translation = value.translation.height
                let velocity = value.velocity.height
                
                let shouldDismiss = translation > contentHeight / 3 || velocity > 1000
                
                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(.sheetAnimation) {
                        currentOffset = 0
                    }
                }
            }
    }
    
    private func dismiss() {
        isShowing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentOffset = 0
            destination?.onDimiss?()
            destination = nil
        }
    }
    
}

