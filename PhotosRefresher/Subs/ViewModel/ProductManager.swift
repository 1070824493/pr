//
//  ProductManager.swift
//  SwiftUITestProject
//
//

struct ScenePackageCache: Equatable {
    var isAudit: Bool
    var packageList: [SubscriptionPackageModel]
    var activityList: [ActivityPackage]
    var closeDelay: Int   // default 0
    var retainTime: Int   // default 0
}

final class ProductManager: ObservableObject {
    static let shared = ProductManager()
    private init() {}
    
    @Published private var packageResp: [String: ScenePackageCache] = [:]
    
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
    func refreshPackageList(_ sendModel: SubscribeListRequestModel) async -> [SubscriptionPackageModel] {
        
        let resp: PRCommonResponse<SubscribeResponseModel>? =
        try? await PRRequestHandlerManager.shared.PRrequest(
            url: ApiConstants.photosrefresher_subscribe_home,
            method: .get,
            parameters: sendModel
        )
        
        guard let resp, resp.succeed() else {
            return packageList(for: PayScene(rawValue: sendModel.scene) ?? .normal)
        }
        
        let d = resp.data
        let payload = ScenePackageCache(
            isAudit: d.isAudit,
            packageList: d.packageList,
            activityList: d.activityList,
            closeDelay: d.closeDelay ?? 0,
            retainTime: d.retainTime ?? 0
        )
        
        await MainActor.run {
            packageResp["\(sendModel.scene)"] = payload
        }
        
        return packageList(for: PayScene(rawValue: sendModel.scene) ?? .normal)
    }
}

extension ProductManager {
    func package(for skuId: Int) -> SubscriptionPackageModel? {
        for (_, sceneCache) in packageResp {
            if let p = sceneCache.packageList.first(where: { $0.skuId == skuId }) {
                return p
            }
        }
        return nil
    }
}
