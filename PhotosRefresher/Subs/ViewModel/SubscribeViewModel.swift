//
//  SubscribeViewModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import UIKit


// 触发购买的上下文（用于决定失败弹窗是否该弹）
public enum PurchaseTriggerContext {
    case manual        // 用户主动点按钮/卡片
    case auto          // 自动拉起
    case exitDetain    // 挽留弹窗上的购买
    case retry         // 失败弹窗的“Try again”
}

/// 订阅页展现来源
public enum PaySource: Int {
    case guided = 0
    case deleteFunc = 1
    case coldOpen = 2
    case explorePage = 3
    case morePage = 4
    case appStorePay = 5
    case chatPage = 6
}

/// 订阅页场景
public enum PayScene: Int { case normal = 1 }
 
class PRSubscribeViewModel: ObservableObject {

    @Published var packageList: [SubscriptionPackageModel] = []
    @Published var selectedPackageId: Int = -1
    @Published var purchasing = false

    var onDismiss: ((_ result: Bool) -> Void)?
    var paySource: PaySource = .guided
    
    private(set) var payScene: PayScene = .normal

    var isAudit: Bool {
        PRProductManager.shared.isAudit(for: payScene)
    }

    var selectPackage: SubscriptionPackageModel? {
        packageList.first { $0.skuId == selectedPackageId }
    }


    // MARK: - Init
    init(paySource: PaySource = .guided, onDismiss: ((_ result: Bool) -> Void)? = nil) {
        self.paySource = paySource
        self.onDismiss = onDismiss
        self.packageList = [
            .init(skuId: 204, priceSale: 1999,  priceFirst: 29,  duration: 7,   recommendSku: true, beOffered: 0, freeDays: 0),
            .init(skuId: 206, priceSale: 3999, priceFirst: 3999, duration: 365, recommendSku: false,  beOffered: 0, freeDays: 0)
        ]
        self.selectedPackageId = packageList.first?.skuId ?? 204
    }

    func initPackageList(paySource: PaySource, payScene: PayScene) async {
        self.paySource = paySource
        self.payScene  = payScene

        
        let cached = PRProductManager.shared.packageList(for: payScene)
        if !cached.isEmpty {
            await MainActor.run {
                self.packageList = cached
            }
        }

        _ = await PRProductManager.shared.refreshPackageList(SubscribeListRequestModel(source: paySource.rawValue, scene: payScene.rawValue)
        )

    }


    
}

//MARK: -- 订阅入口
extension PRSubscribeViewModel {
    
    @discardableResult
    func purchase(package: SubscriptionPackageModel? = nil) async -> Bool {
        guard let pkg = package ?? selectPackage else { return false }
        guard pkg.skuId > 0 else { return false }

        let alreadyPurchasing = await MainActor.run {
            purchasing
        }
        if alreadyPurchasing {
            return false
        }
        await MainActor.run {
            purchasing = true
        }
        defer {
            Task {
                await MainActor.run { purchasing = false }
            }
        }

        let isFreeTrial = pkg.freeDays > 0
        await MainActor.run {
            PRGlobalOverlay.shared.present {
                PRHomeHUDView(type: isFreeTrial ? .freeTrial : .normal) {
                    PRGlobalOverlay.shared.dismiss()
                }
            }
        }
        defer {
            Task { @MainActor in
                PRGlobalOverlay.shared.dismiss()
            }
        }

        // 已订阅兜底
        if PRUserManager.shared.isVip() {
            return true
        }

        let traceId = "\(CommonAICuid.sharedInstance().getDeviceADID())_\(Date.currentTimestamp())"

        let result = await PROrderManager.shared.PRpaySubscription(
            skuId: pkg.skuId,
            paySource: paySource.rawValue,
            traceId: traceId
        )

        switch result {
        case .success(_):
            let isVip = await refreshVip()

            await MainActor.run {
                if isVip {
                    PRToast.show(message: "Transaction successful", duration: 3.0)
                } else {
                    PRToast.show(message: "Payment successful. Your benefits will be delivered shortly, please wait", duration: 3.0)
                }
            }
            return true

        case .failure(let err):

            switch err.code {
            case .alreadyInProgress:
                PRToast.show(message: "Purchase already in progress", duration: 3)
            default:
                PRToast.show(message: "Payment failed", duration: 3)
            }

            return false
        }

    }
    
    private func refreshVip() async -> Bool {
        let maxRetries = 2
        var retry = 0
        while retry <= maxRetries {
            if retry != 0 {
                let delay = pow(2.0, Double(retry))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            let ok = await PRUserManager.shared.refreshUserInfo()
            if ok, PRUserManager.shared.isVip() { return true }
            retry += 1
        }
        return PRUserManager.shared.isVip()
    }
}

//MARK: -- 点击事件
extension PRSubscribeViewModel {
    func restore() {
        Task {
            let succeed = await PROrderManager.shared.restore()
            await MainActor.run {
                PRToast.show(message: succeed ? "Restore successful" : "Restore failed")
            }
        }
    }

    func openUrl(_ url: String) {
        guard let url = URL(string: url), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    func back(_ result: Bool) {
        onDismiss?(result)
    }
}

//MARK: -- 商品的一些展示文案
extension PRSubscribeViewModel {
    
    func titleFor(_ p: SubscriptionPackageModel) -> String {
        if isAudit {
            var times: String = "day"
            switch p.duration {
                case 365: times = "year"
                case 30: times = "month"
                case 7: times = "week"
                default: times = "day"
            }
            
            let auditlast = "$\(p.priceSaleReal)/\(times)"
            let beOfferedAudit: String = (isFirstOfferDisplay(p) && p.priceFirstReal < p.priceSaleReal) ? "1 \(times) $\(p.priceFirstReal), then " : ""
            let freeDaysAudit: String = isFreeTrialDisplay(p) ? "\(p.freeDays) day free, then " : ""
            return freeDaysAudit + beOfferedAudit + auditlast
        } else {
            switch p.duration {
                case 365: return "Monthly Access"
                case 30: return "Weekly Access"
                default: return "7-Day Full Access"
            }
        }
    }
    
    func switchTitle(_ p: SubscriptionPackageModel) -> String {
        var times: String = "day"
        switch p.duration {
            case 365: times = "year"
            case 30: times = "month"
            case 7: times = "week"
            default: times = "day"
        }
        
        let auditlast = "$\(p.priceSaleReal)/\(times)"
        let beOfferedAudit: String = (isFirstOfferDisplay(p) && p.priceFirstReal < p.priceSaleReal) ? "1 \(times) $\(p.priceFirstReal), then " : ""
        let freeDaysAudit: String = isFreeTrialDisplay(p) ? "\(p.freeDays) day free, then " : ""
        return freeDaysAudit + beOfferedAudit + auditlast
    }
    
    func durationForDisplay(_ p: SubscriptionPackageModel) -> String {
        if isAudit {
            return "auto-renew, cancel anytime."
        }
        if isFreeTrialDisplay(p) {
            return "Day Free Trial"
        }
        switch p.duration {
            case 365: return "SAVE 93%！"
            case 30: return "BEST VALUE"
            default: return "MOST POPULAR"
        }
    }
    
    private func isFreeTrialDisplay(_ p: SubscriptionPackageModel) -> Bool {
        (p.freeDays > 0) ? true : false
    }
    
    private func isFirstOfferDisplay(_ p: SubscriptionPackageModel) -> Bool {
        p.beOffered == 0
    }
    
    func priceForDisplay(_ p: SubscriptionPackageModel) -> String {
        if isAudit {
            return ""
        }
        if isFreeTrialDisplay(p) { return "$0.00" }
        var base = p.priceSaleReal
        if isFirstOfferDisplay(p) && (p.priceFirstReal < p.priceSaleReal) {
            base = p.priceFirstReal
        }
            switch p.duration {
            case 365: return currency(base / 12.0)
            case 30: return currency(base / 4.0)
            default: return currency(base)
        }
    }
    
    private func currency(_ v: Double) -> String { String(format: "$%.2f", v) }
}

