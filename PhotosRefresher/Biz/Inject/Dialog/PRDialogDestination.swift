//
//  DialogDestination.swift

//
//

import SwiftUI

public enum AppBottomSheetDestination {
    
    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        default:
            EmptyView()
        }
    }
    
    // 是否有背景蒙层
    var hasMask: Bool {
        switch self {
        default:
            true
        }
    }
    
    // 点击空白区域关闭
    var dismissOnTapOutside: Bool {
        switch self {
        default:
            true
        }
    }
    
    // 是否支持手势拖拽
    var draggable: Bool {
        switch self {
        default:
            true
        }
    }
    
    // 最大高度
    var maxHeight: Float {
        switch self {
        default:
            .infinity
        }
    }
    
    // 关闭回调
    var onDimiss: (() -> Void)? {
        switch self {
        default:
            nil
        }
    }
    
}

public enum AppModalDestination {
    case trashReview(model: TrashReviewViewModel)
    
    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        case .trashReview(let model):
            TrashReviewAlertView(model: model)
        }
    }
    
    var usesCardContainer: Bool {
        switch self {
        default:
            return true
        }
    }
    
    // 是否有背景蒙层
    var hasMask: Bool {
        switch self {
        default:
            return true
        }
    }
    
    // 点击空白区域关闭
    var dismissOnTapOutside: Bool {
        switch self {
        default:
            return true
        }
    }
    
    // 最大高度
    var maxHeight: Float {
        switch self {
        default:
            .infinity
        }
    }
    
    // 关闭回调
    var onDismiss: () -> Void {
        switch self {
        case .trashReview(let model):
            return model.onDismiss ?? {}
        }
    }
}
