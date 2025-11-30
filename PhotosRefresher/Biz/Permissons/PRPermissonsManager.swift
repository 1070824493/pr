//
//  PRPermissionManager.swift


import UIKit
import AVFoundation
import AppTrackingTransparency
import AdSupport

@objc enum AuthStatus: Int {
    case notDetermined = -1
    case off
    case authorized
    case setting
}

@objcMembers class PRPermissionManager: NSObject {

    static let shared = PRPermissionManager()
    
    private override init() {}
    
    private static var shouldRequestTracking: Bool = false {
        didSet {
            if shouldRequestTracking {
                Self.requestTrackingPermission {
                    
                }
            }
        }
    }
    
    @objc static var canShowIDFA: Bool = false {
        didSet {
            if canShowIDFA {
                shouldRequestTracking = true
            }
        }
    }

    func queryTrackingAuthorizationStatus(shouldRequest: Bool = false) -> AuthStatus {
        if shouldRequest {
            if #available(iOS 14.5, *) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
            return .setting
        }
        
        return determineTrackingPermissionState()
    }
    
    private func determineTrackingPermissionState() -> AuthStatus {
        if #available(iOS 14.5, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .notDetermined:
                return .notDetermined
            case .denied, .restricted:
                return .off
            case .authorized:
                return .authorized
            @unknown default:
                fatalError()
            }
        } else {
            let isTrackingEnabled = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
            return isTrackingEnabled ? .authorized : .off
        }
    }
    
    static func requestTrackingPermission(completion: @escaping () -> Void) {
        if #available(iOS 14, *) {
            let currentStatus = PRPermissionManager.shared.queryTrackingAuthorizationStatus()
            if currentStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    completion()
                }
            } else {
                completion()
            }
        } else {
            completion()
        }
    }
    
}
