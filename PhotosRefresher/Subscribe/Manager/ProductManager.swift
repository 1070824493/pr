//
//  ProductManager.swift
//  SwiftUITestProject
//
//



struct ScenePackageCache: Equatable {
    var isAudit: Bool
    var packageList: [SubscriptionPackage]
    var activityList: [ActivityPackage]
    var closeDelay: Int   // default 0
    var retainTime: Int   // default 0
}

final class ProductManager: ObservableObject {
    static let shared = ProductManager()
    private init() {}

    @Published private var cache: [String: ScenePackageCache] = [:]

    func packageList(for scene: PayScene = .normal) -> [SubscriptionPackage] {
        cache["\(scene.rawValue)"]?.packageList ?? []
    }
    func activityList(for scene: PayScene = .normal) -> [ActivityPackage] {
        cache["\(scene.rawValue)"]?.activityList ?? []
    }
    func isAudit(for scene: PayScene = .normal) -> Bool {
        cache["\(scene.rawValue)"]?.isAudit ?? false
    }
    func closeDelay(for scene: PayScene = .normal) -> Int {
        cache["\(scene.rawValue)"]?.closeDelay ?? 0
    }
    func retainTime(for scene: PayScene = .normal) -> Int {
        cache["\(scene.rawValue)"]?.retainTime ?? 0
    }
    
    @discardableResult// 允许调用方忽略返回值
    func refreshPackageList(_ sendModel: SubscribeHomeSendModel) async -> [SubscriptionPackage] {
        let start = Date.currentTimestamp()

        let resp: CommonResponse<SubscriptionPackageResponse>? =
            try? await NetworkManager.shared.request(
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
            cache["\(sendModel.scene)"] = payload
        }

//        StatisticsManager.log(
//            name: "PACKAGE_LIST_COST",
//            params: ["cost": Date.currentTimestamp() - start]
//        )
        return packageList(for: PayScene(rawValue: sendModel.scene) ?? .normal)
    }
}

extension ProductManager {
    func package(for skuId: Int) -> SubscriptionPackage? {
        for (_, sceneCache) in cache {
            if let p = sceneCache.packageList.first(where: { $0.skuId == skuId }) {
                return p
            }
        }
        return nil
    }
}
