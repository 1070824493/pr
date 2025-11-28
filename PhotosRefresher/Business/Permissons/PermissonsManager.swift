//
//  PermissonsManager.swift
//  QuestionAI
//
//  Created by changyiyi on 2022/3/14.
//  Copyright © 2022 作业帮口算. All rights reserved.
//  权限管理类 get、set

import UIKit
import AVFoundation
import AppTrackingTransparency
import AdSupport

@objc enum AuthStatus: Int {
    case notDetermined = -1
    case off
    case authorized
    case setting // 仅表示一个状态，没实际意义
}

@objcMembers class PermissionManager: NSObject {

    // Make sure the class has only one instance
    static let shared = PermissionManager()
    
    // Should not init outside
    private override init() {}
    
    @objc static var canShowIDFA: Bool = false {
        didSet {
            if canShowIDFA {
                PermissionManager.showIDFA {
                    
                }
            }
        }
    }
}

extension PermissionManager {
    
    
    
    /// idfa权限
    func checkIDFAStatus(_ isSetting: Bool = false) -> AuthStatus {
        if isSetting == true {
            if #available(iOS 14.5, *) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
            return .setting
        }
        if #available(iOS 14.5, *) {
            let authStatus = ATTrackingManager.trackingAuthorizationStatus
            switch authStatus {
            case .notDetermined: // 用户还没有选择
                return .notDetermined
            case .denied, .restricted: // 用户拒绝、家长控制
                return .off
            case .authorized: // 已授权
                return .authorized
            @unknown default:
                fatalError()
            }
        } else {
            let authStatus = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
            return (authStatus == true ? .authorized : .off)
        }
    }
    
    static func showIDFA(callback: @escaping () -> Void) {
        if #available(iOS 14, *) {
            // idfa 系统弹窗
            let authStatus = PermissionManager.shared.checkIDFAStatus()
            if authStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    callback()
                }
            } else {
                callback()
            }
        } else {
            callback()
        }
    }
}