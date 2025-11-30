//
//  TrackingUtils.swift
//

import Foundation
import AppTrackingTransparency
import AdSupport

class PRIdfaUtils {
    
    static let instance = PRIdfaUtils()
    
    private var cachedIdfa: String = ""
    
    private init() {}
    
    /// 同步获取 IDFA
    func fetchIdfaSync() -> String {
        return cachedIdfa
    }
    
    /// 异步请求 IDFA
    @MainActor
    func requestIdfaAuthorization() async -> String {
        if !cachedIdfa.isEmpty {
            return cachedIdfa
        }
        
        var authorizationStatus = ATTrackingManager.trackingAuthorizationStatus
        if authorizationStatus == .notDetermined {
            authorizationStatus = await ATTrackingManager.requestTrackingAuthorization()
        }
        
        switch authorizationStatus {
        case .authorized:
            cachedIdfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        default:
            cachedIdfa = ""
        }
        
        return cachedIdfa
    }
}
