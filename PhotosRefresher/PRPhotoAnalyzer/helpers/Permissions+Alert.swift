//
//  Permissions+Alert.swift

//

//

import Foundation
import Photos
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension PRPhotoMapManager {
    /// 权限受限提示弹窗（引导前往设置）
    func showSettingsRedirectAlert(for status: PHAuthorizationStatus) {
        let (title, message): (String, String) = {
            switch status {
            case .denied:
                return ("Unlock Full PR",
                        "We need access to your photos to detect duplicates, large files, and blurry shots. Enable photo access in Settings and start freeing up space now!")
            case .restricted:
                return ("Photo Access Restricted",
                        "Photo access is blocked by system or parental controls. Without it, we can't analyze your library or help you reclaim storage space.")
            case .limited:
                return ("Get Maximum Space Savings",
                        "Currently only a few photos are accessible. Grant access to your entire library in Settings to clean up faster and reclaim the most storage.")
            default:
                return ("Photo Access Needed",
                        "Enable photo access in Settings to scan your library, remove clutter, and instantly free up valuable space.")
            }
        }()
        permissionAlert = PRAlertModalModel(
            imgName: "", title: title, desc: message,
            firstBtnTitle: "Not Now", secondBtnTitle: "Open Settings",
            actionHandler: { [weak self] action in
                switch action {
                case .first:
                    self?.permissionAlert?.onDismiss?(); self?.permissionAlert = nil
                case .second:
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    self?.permissionAlert?.onDismiss?(); self?.permissionAlert = nil
                }
            },
            onDismiss: { [weak self] in
                self?.permissionAlertOnDismiss?()
                self?.permissionAlertOnDismiss = nil
                self?.permissionAlert = nil
            }
        )
    }
}
