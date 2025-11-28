//
//  PurchaseCoordinator.swift
//  Dialogo
//

//

import Foundation


enum PurchaseFlowResult {
    case success(isVip: Bool, transId: String, transOriginalID: String)
    case cancelled
    case alreadyInProgress
    case failed(code: Int, message: String)
}

actor PurchaseCoordinator {
    static let shared = PurchaseCoordinator()
    private var inProgress = false
    

    /// 统一对外购买入口
    /// - Parameters:
    ///   - skuId: 要购买的 SKU
    ///   - paySource: 购买来源
    ///   - contentType: 你的埋点用类型（13/1/12）；若不传则不打这项
    ///   - revenueRaw: 可选，用于打点的价格原始值（x1000）
    func purchase(product: SubscriptionPackage,
                  paySource: PaySource,
                  contentType: Int? = nil,
                  revenueRaw: Float? = nil) async -> PurchaseFlowResult {

        guard !inProgress else { return .alreadyInProgress }
        inProgress = true
        defer { inProgress = false }
        let skuId = product.skuId
        if skuId == 0 {
            return .cancelled
        }
        
        // 显示 HUD（加到 window）
        let isFreeTrial = product.freeDays > 0
        await MainActor.run {
            GlobalOverlay.shared.present {
                PRHomeHUDView(type: isFreeTrial ? .freeTrial : .normal) {
                    GlobalOverlay.shared.dismiss()
                }
            }
        }
        defer {
            Task { @MainActor in
                GlobalOverlay.shared.dismiss()
            }
        }

        // 已订阅兜底
        if UserManager.shared.isVip() {
            return .success(isVip: true, transId: "", transOriginalID: "")
        }

        // 打点：发起
        var marketParams: [String: Any] = ["af_currency": "USD"]
        if let ct = contentType { marketParams["af_content_type"] = ct }
        if let rv = revenueRaw { marketParams["af_revenue"] = rv }
        MarketManager.shared.reportServer(name: MarkerReportEvent.subscription_btn_click, params: marketParams)
        MarketManager.shared.uploadFaceBook(name: "InitiatedCheckout", params: [
            "ContentType": "product",
            "ContentID": product.skuId,
            "Currency": "USD",
            "PaymentInfoAvailable": 1,
            "NumItems": 1
        ])
//        StatisticsManager.log(name: "JHP_002", params: [
//            "paySource": paySource.rawValue,
//            "skuid": product.skuId,
//            "newuser_guide": paySource == .guided ? "1" : "0",
//            "subscription": 1,
//            "from": String(ConfigManager.shared.appConfig?.paywallVariant.rawValue ?? 1)
//        ])

        let traceId = "\(CommonAICuid.sharedInstance().getDeviceADID())_\(Date.currentTimestamp())"

        let result = await PurchaseManager.shared.purchaseSubscription(
            skuId: product.skuId,
            paySource: paySource.rawValue,
            traceId: traceId
        )

        switch result {
        case .success(let trans):
            let isVip = await pollVip()
//            StatisticsManager.log(name: "JHP_003", params: [
//                "paySource": paySource.rawValue,
//                "skuid": product.skuId,
//                "transId": trans.id,
//                "transOriginalID": trans.originalID,
//                "isVip": isVip,
//                "newuser_guide": paySource == .guided ? "1" : "0",
//                "subscription": 1,
//                "from": String(ConfigManager.shared.appConfig?.paywallVariant.rawValue ?? 1)
//            ])
            if isFreeTrial {
                MarketManager.shared.uploadFaceBook(name: "StartTrial", params: [
                    "OrderID": trans.id,
                    "Currency": "USD"
                ])
            }
            MarketManager.shared.uploadFaceBook(name: "Purchase", params: [
                "ContentType": "product",
                "ContentID": product.skuId,
                "Currency": "USD",
                "NumItems": 1
            ])
            if let registerTime = UserManager.shared.userInfo?.registerTime,
                              registerTime > 0,
               Date(timeIntervalSince1970: TimeInterval(registerTime)).isToday() {
                MarketManager.shared.uploadFaceBook(name: "AddedToCart", params: [
                    "ContentType": "product",
                    "ContentID": product.skuId,
                    "Currency": "USD"
                ])
            }
            
            return .success(
                isVip: isVip,
                transId: "\(trans.id)",
                transOriginalID: "\(trans.originalID)"
            )

        case .failure(let err):
            // 区分用户取消 & 订单已存在等情况
//            StatisticsManager.log(name: "JHP_004", params: [
//                "paySource": paySource.rawValue,
//                "skuid": product.skuId,
//                "txt": err.errorCode,
//                "errorMsg": err.errorMsg,
//                "newuser_guide": paySource == .guided ? "1" : "0",
//                "subscription": 1,
//                "from": String(ConfigManager.shared.appConfig?.paywallVariant.rawValue ?? 1)
//            ])

            if err.code == .userCancelled {
                return .cancelled
            } else if err.code == .reportOrderFailed || err.code == .isPurchased {
                // 这两类按成功兜底（与现有逻辑一致）
                let isVip = UserManager.shared.isVip()
                return .success(isVip: isVip, transId: "", transOriginalID: "")
            } else {
//                try? await Task.sleep(nanoseconds: 6_000_000_000) // 0.6 秒
                return .failed(code: err.errorCode, message: err.errorMsg)
            }
        }
    }

    /// 购买后轮询 VIP（指数回退）
    private func pollVip() async -> Bool {
        let maxRetries = 2
        var retry = 0
        while retry <= maxRetries {
            if retry != 0 {
                let delay = pow(2.0, Double(retry))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            let ok = await UserManager.shared.refreshUserInfo()
            if ok, UserManager.shared.isVip() { return true }
            retry += 1
        }
        return UserManager.shared.isVip()
    }
}

