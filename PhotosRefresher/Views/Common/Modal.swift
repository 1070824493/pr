//
//  Modal.swift

//
//

import SwiftUI

struct ModalView: View {
    @Binding var destination: AppModalDestination?
    
    @State private var contentHeight: CGFloat = 0
    
    private var hasMask: Bool {
        destination?.hasMask ?? true
    }
    
    private var dismissOnTapOutside: Bool {
        destination?.dismissOnTapOutside ?? true
    }
    
    private var maxHeight: CGFloat {
        let value = destination?.maxHeight ?? .infinity
        return value == .infinity ? .infinity : CGFloat(value)
    }
    
    private var effectiveMaxHeight: CGFloat {
        if maxHeight.isInfinite {
            return kScreenHeight
        } else {
            return min(maxHeight, kScreenHeight)
        }
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            maskView
                .ignoresSafeArea(.all)
                .onTapGesture {
                    if dismissOnTapOutside {
                        dismiss()
                    }
                }
            
            modalContent
        }
        .ignoresSafeArea(.all)
//        .transition(.asymmetric(
//            insertion: .opacity.animation(
//                .easeInOut(duration: 0.0)
//            ),
//            removal: .opacity.animation(
//                .modalAnimation
//            )
//        ))
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
    
    private var modalContent: some View {
        Group {
            if destination?.usesCardContainer == true {
                VStack(spacing: 0) {
                    if contentHeight > effectiveMaxHeight {
                        ScrollView(showsIndicators: false) { contentView }
                            .frame(maxHeight: effectiveMaxHeight)
                    } else {
                        contentView
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: fitScale(16), style: .continuous))
                .padding(.horizontal, 15)
            } else {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
        }
    }
    
    private var contentView: some View {
        destination?.makeContentView()
            .readSize { size in
                contentHeight = size.height
            }
    }
    
    private func dismiss() {
        destination?.onDismiss()
        destination = nil
    }
    
}

