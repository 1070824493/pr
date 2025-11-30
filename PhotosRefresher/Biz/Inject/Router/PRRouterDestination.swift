//
//  RouterDestination.swift

//
//

import Foundation
import UIKit

public enum AppRouterDestination {
    
    
    case exploreDoubleFeed(cardID: PRAssetType, isVideo: Bool)
    case exploreSecondRepeat(cardID: String)
    case slideDetail(category: PRAssetType)
    case settingPage

}

public enum AppFullScreenCoverDestination: Identifiable, Hashable {
    
    case systemShare(images: [UIImage], files: [URL])
    
    public static func == (lhs: AppFullScreenCoverDestination, rhs: AppFullScreenCoverDestination) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    case exploreDeleteFinish(count: Int64, deletedText: String, storageSize: Int64, onDismiss: (() -> Void)? = nil)
    case subscription(paySource: PaySource, onDismiss: ((_ isSuccess: Bool) -> Void)? = nil)
    
    public var id: String {
        switch self {
        case .exploreDeleteFinish(count: 0, deletedText: "0", storageSize: 0, onDismiss: nil):
            "exploreDeleteFinish"
        default:
            ""
        }
    }
    
}
