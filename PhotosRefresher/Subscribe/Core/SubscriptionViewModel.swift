//
//  SubscriptionViewModel.swift
//  SwiftUITestProject
//

import Foundation
import UIKit

import AVFoundation

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

final class SubscriptionViewModel: ObservableObject {

    @Published var packageList: [SubscriptionPackage] = []
    @Published var selectedPackageId: Int = -1
    @Published var purchasing = false

    private(set) var paySource: PaySource = .guided
    private(set) var payScene: PayScene = .normal

    // 审核状态
    var isAuditBuild: Bool {
        ProductManager.shared.isAudit(for: payScene)
    }

    // 挽留弹窗：只在 .guided 且非审核下可用，且只弹一次 ======
    @Published var exitAlertShownOnce = false
    var isExitAlertEligible: Bool { paySource == .guided && !isAuditBuild && !exitAlertShownOnce }
    @MainActor func markExitAlertShown() { exitAlertShownOnce = false }

    // 自动拉起：只在 .guided 且非审核下“有资格” ======
    var isAutoPayEligibleBySource: Bool {
            paySource == .guided
            && !isAuditBuild
            && !exitAlertShownOnce
            && !purchasing
            && !packageList.isEmpty
        }
    // 固定 15s
    var autoPayDelaySeconds: Int = 15

    // 挽留页推荐商品：活动第一项的第一个；若无就用当前选中 ======
    var detainPageProduct: SubscriptionPackage? {
        ProductManager.shared.activityList().first?.packageList.first ?? selectPackage
    }
    // 当前选中的商品 ======
    var selectPackage: SubscriptionPackage? {
        packageList.first { $0.skuId == selectedPackageId }
    }
    var selectedOrFirstPackage: SubscriptionPackage? {
        selectPackage ?? packageList.first
    }
    // 判断当前选择的商品是否显示“免费试用”
    var isFreeTrialDisplay: Bool {
        if isAuditBuild { return false }
        return (selectedOrFirstPackage?.freeDays ?? 0) > 0
    }

    // 购买失败弹窗：失败就弹不分PaySource场景，审核包不弹 + 弹窗的购买不弹 ======
    var payFailureAlertOnce = false
    @MainActor
    func shouldShowFailureAlert(context: PurchaseTriggerContext) -> Bool {
        // 审核包不弹
        if isAuditBuild { return false }
        // 只弹一次
//        if payFailureAlertOnce { return false }
        // 仅“手动”弹；自动拉起/挽留/失败重试均不弹
        guard context == .manual else { return false }
//        payFailureAlertOnce = true
        return true
    }

    // 供埋点：13/1/12
    var selectPackageType: Int {
        switch selectPackage?.duration {
        case 7:   return 13
        case 30:  return 1
        case 365: return 12
        default:  return 0
        }
    }

    // MARK: - Init
    init() {
        self.packageList = [
            .init(skuId: 127, priceSale: 999,  priceFirst: 29,  price: 999,  duration: 7,   recommendSku: true, beOffered: 0, freeDays: 0),
            .init(skuId: 129, priceSale: 3499, priceFirst: 3499, price: 3499, duration: 365, recommendSku: false,  beOffered: 0, freeDays: 0)
        ]
        self.selectedPackageId = packageList.first?.skuId ?? 127
    }

    func initPackageList(paySource: PaySource, payScene: PayScene) async {
        self.paySource = paySource
        self.payScene  = payScene

        // 1) 先用缓存渲染首屏
        let cached = ProductManager.shared.packageList(for: payScene)
        if !cached.isEmpty {
            await MainActor.run {
                self.packageList = cached
                self.autoSelectRecommendProduct()
            }
        }

        // 2) 刷新网络并更新缓存/界面
        let curList = await ProductManager.shared.refreshPackageList(
            SubscribeHomeSendModel(source: paySource.rawValue, scene:  payScene.rawValue)
        )

        await MainActor.run {
            if cached.isEmpty || !curList.isEmpty {
                // 如果想启用云控结果，放开这两行：
                // self.packageList = curList
                // self.autoSelectRecommendProduct()
            }
        }

        MarketManager.shared.reportServer(name: MarkerReportEvent.subscription_page_show)
        MarketManager.shared.uploadFaceBook(name: "Subscribe")
//        StatisticsManager.log(name: "JHP_001", params: ["paySource": paySource.rawValue, "subscription": 1, "from": String(ConfigManager.shared.appConfig?.paywallVariant.rawValue ?? 1)])
    }

    /// 根据 recommendSku 自动选择；若无推荐则选首个；若已有选中且仍存在，则保持。
    @MainActor
    func autoSelectRecommendProduct() {
        let keepIfStillExists = packageList.contains(where: { $0.skuId == selectedPackageId })
        if keepIfStillExists { return }
        if let rec = packageList.first(where: { $0.recommendSku }) {
            selectedPackageId = rec.skuId
        } else {
            selectedPackageId = packageList.first?.skuId ?? -1
        }
    }

    func restore() {
        Task {
            let succeed = await PurchaseManager.shared.restore()
            await MainActor.run {
                Toast.show(message: succeed ? "Restore successful" : "Restore failed")
            }
        }
    }

    // MARK: - External
    func openUrl(_ url: String) {
        guard let url = URL(string: url), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

extension SubscriptionViewModel {
    /// 返回 true 表示“可视为成功”，false 交由页面决定是否弹失败重试
    func purchase(paySource: PaySource, package: SubscriptionPackage?) async -> Bool {
        guard let pkg = package else { return false }
        guard pkg.skuId > 0 else { return false }

        let contentType: Int = {
            switch pkg.duration {
            case 7:   return 13
            case 30:  return 1
            case 365: return 12
            default:  return 0
            }
        }()

        let revenueRaw = pkg.priceSale

        let alreadyPurchasing = await MainActor.run { purchasing }
        if alreadyPurchasing { return false }
        await MainActor.run { purchasing = true }
        defer { Task { await MainActor.run { purchasing = false } } }

        let flowResult = await PurchaseCoordinator.shared.purchase(
            product: pkg,
            paySource: paySource,
            contentType: contentType == 0 ? nil : contentType,
            revenueRaw: revenueRaw
        )

        switch flowResult {
        case .alreadyInProgress, .cancelled, .failed:
            return false

        case .success(let isVip, _, _):
            await MainActor.run {
                if isVip {
                    Toast.show(message: "Transaction successful", duration: 3.0)
                } else {
                    Toast.show(message: "Payment successful. Your benefits will be delivered shortly, please wait", duration: 3.0)
                }
            }
            return true
        }
    }
}

class SoundManager {
    static let instance = SoundManager()
        
    func playSound(named soundName: String? = nil, isSystemSound: Bool = false) {
        if isSystemSound {
            // 播放系统声音
            AudioServicesPlaySystemSound(1111)
        } else if let soundName = soundName {
            // 播放自定义声音
            guard let url = Bundle.main.url(forResource: soundName, withExtension: ".mp3") else { return }
            
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.play()
            } catch let error {
                print("播放声音错误: \(error.localizedDescription)")
            }
        }
    }
}
