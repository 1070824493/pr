//
//  IdfaUtils.swift
//

import Foundation
import AppTrackingTransparency
import AdSupport

class IdfaUtils {
    
    public static let shared = IdfaUtils()
    
    private var idfaCache = ""
    
    private init() {}
    
    func getIdfaSync() -> String {
        return idfaCache
    }
    
    @MainActor
    func requestIdfa() async -> String {
        if (!idfaCache.isEmpty) {
            return idfaCache
        }
        
        var status = ATTrackingManager.trackingAuthorizationStatus
        if (status == ATTrackingManager.AuthorizationStatus.notDetermined) {
            status = await ATTrackingManager.requestTrackingAuthorization()
        }
        
        switch status {
        case ATTrackingManager.AuthorizationStatus.authorized:
            idfaCache = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        default:
            idfaCache = ""
        }

        return idfaCache
    }
    
}
