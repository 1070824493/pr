//
//  ProductManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation

final class PRProductManager: ObservableObject {
    static let shared = PRProductManager()
    private init() {}
    
    @Published private var packageResp: [String: PRSubscribeResponseModel] = [:]
    
    func packageList(for scene: PayScene = .normal) -> [SubscriptionPackageModel] {
        packageResp["\(scene.rawValue)"]?.packageList ?? []
    }
    func activityList(for scene: PayScene = .normal) -> [ActivityPackage] {
        packageResp["\(scene.rawValue)"]?.activityList ?? []
    }
    func isAudit(for scene: PayScene = .normal) -> Bool {
        packageResp["\(scene.rawValue)"]?.isAudit ?? false
    }
    func closeDelay(for scene: PayScene = .normal) -> Int {
        packageResp["\(scene.rawValue)"]?.closeDelay ?? 0
    }
    func retainTime(for scene: PayScene = .normal) -> Int {
        packageResp["\(scene.rawValue)"]?.retainTime ?? 0
    }
    
    @discardableResult
    func refreshPackageList(_ sendModel: PRSubscribeListRequestModel) async -> [SubscriptionPackageModel] {
        
        let resp: PRCommonResponse<PRSubscribeResponseModel>? =
        try? await PRRequestHandlerManager.shared.PRrequest(
            url: ApiConstants.photosrefresher_subscribe_home,
            method: .get,
            parameters: sendModel
        )
        
        guard let resp, resp.succeed() else {
            return packageList(for: PayScene(rawValue: sendModel.scene) ?? .normal)
        }
        
        let d = resp.data
       
        
        await MainActor.run {
            packageResp["\(sendModel.scene)"] = d
        }
        
        return packageList(for: PayScene(rawValue: sendModel.scene) ?? .normal)
    }
}

extension PRProductManager {
    func package(for skuId: Int) -> SubscriptionPackageModel? {
        for (_, sceneCache) in packageResp {
            if let p = sceneCache.packageList.first(where: { $0.skuId == skuId }) {
                return p
            }
        }
        return nil
    }
}
