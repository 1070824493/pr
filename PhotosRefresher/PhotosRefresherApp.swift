//
//  PhotosRefresherApp.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/19.
//

import SwiftUI
import UIKit
//import AppsFlyerLib

@main
struct PhotosRefresherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateAdaptor.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var uiState = UIState.shared
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .withEnvironments()
                .withBottomSheet($uiState.bottomSheetDestination)
                .withModal($uiState.modalDestination)
                .withFullScreenCoverRouter($uiState.fullScreenCoverDestination)
                .onAppear(perform: setupAppearance)
                .onOpenURL(perform: handleURL(url:))
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        applicationDidBecomeActive()
                    }
                }
        }
    }
    
    private func handleURL(url: URL) {
        // TODO: handle scheme
    }
    
    private func setupAppearance() {
        // TODO: support dark mode
        if #available(iOS 16.4, *) {
            handlePurchaseIntent()
        }
    }
    
    private func applicationDidBecomeActive() {
        Task {
            if (NetworkObserver.shared.isReachable) {
                let _ = await IdfaUtils.shared.requestIdfa()
            }
        }
//        AppsFlyerLib.shared().start()
        
    }
    
    @available(iOS 16.4, *)
    func handlePurchaseIntent() {
        PurchaseManager.shared.listenForPurchaseIntent { intent in
            Task {
                do {
                    let productId = intent.product.id
                    guard !productId.isEmpty else { return }
                    let params: [String:String] = ["iapId": productId]
                    let resp: CommonResponse<ProductInfoDTO> = try await NetworkManager.shared.request(
                        url: ApiConstants.photosrefresher_product_getProductInfo,
                        method: .get,
                        parameters: ["iapId": productId]
                    )
                    let product = SubscriptionPackage(skuId: Int(resp.data.skuId), priceSale: 0, priceFirst: 0, price: 0, duration: 0, recommendSku: false, beOffered: 0, freeDays: 0)
                    let flowResult = await PurchaseCoordinator.shared.purchase(
                        product: product,
                        paySource: .appStorePay
                    )
                     await MainActor.run {
                         switch flowResult {
                             case .alreadyInProgress:
                                 Toast.show(message: "Purchase already in progress", duration: 3)
                             case .cancelled, .failed:
                                 Toast.show(message: "Payment failed", duration: 3)
                             case .success(let isVip, _, _):
                                 Toast.show(message: isVip ? "Transaction successful"
                                                           : "Payment successful. Benefits will arrive soon", duration: 3)
                             }
                     }
                } catch {
                    await MainActor.run { Toast.show(message: "Payment failed", duration: 3) }
                }
            }
        }
    }
    
    
}

class AppDelegateAdaptor: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        initEnv()
        initLog(application, didFinishLaunchingWithOptions: launchOptions)
        initNetwork()
        initPurchaseManager()
        listenNetWork()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        // TODO: notification
    }
    
//    func application(
//        _ app: UIApplication,
//        open url: URL,
//        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
//    ) -> Bool {
//        // 暂时用不到facebook登录
//        return ApplicationDelegate.shared.application(
//            app,
//            open: url,
//            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
//            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
//        )
//    }
    
    private func initEnv() {
        EnvManager.shared.initEnv(domainConfigs: [
            "aivory": (
                onlineDomain: AppDomainConstants.business_online_domain,
                testDomain: AppDomainConstants.business_test_domain
            ),
            "unifypay": (
                onlineDomain: AppDomainConstants.unifypay_cleanai_online_domain,
                testDomain: AppDomainConstants.unifypay_cleanai_test_domain
            )
        ], inEnvName: AppInfo.envName)
    }
    
    private func initNetwork() {
        NetworkSignUtils.registerKeys(
            privateKey: CommonAICuid.sharedInstance().getDeviceADID(),
            randomKey1: "S#ZCL@%V8T7D<MW#",
            randomKey2: "oc]s#LuxaFG>Atx(",
            randomKey3: "K*;z(i",
            prefixKey: "xtU7w90{g9@MqRH2"
        )
        NetworkManager.shared.registerDynamicCommonParamsProvider(provider: AppInfo.self)
        NetworkManager.shared.addCommonParameters(AppInfo.staticCommonParams)
    }
    
    private func initPurchaseManager() {
        PurchaseManager.shared.initialize(
            createSubscriptionOrderApi: ApiConstants.photosrefresher_create_order,
            reportOrderApi: ApiConstants.photosrefresher_report_order,
            traceOrderApi: ApiConstants.photosrefresher_trace_order
        )
        PurchaseManager.shared.registerCallback { result in
            guard case .success(_) = result else {
                print("Not a success")
                return
            }
        }
        PurchaseManager.shared.listenForTransactionUpdates()
    }
    
    func listenNetWork() {
        NetworkObserver.shared.startListening { online in
            if online {
                Task {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    let _ = await IdfaUtils.shared.requestIdfa()
                }
            }
        }
    }
    
    func initLog(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) {
//        let testUploadUrl = "https://report.myplantai.com/log/app_test"
//        let onlineUploadUrl = "https://report.myplantai.com/log/cf_app"
//        let configUrl = "https://qaistats.studyquicks.com/stats/OB-LLEARN-I.json"
//        let zpid = "OB-AC-I"
//        let platId = "acAPP"
//        let statisticsAppInfoProvider = StatisticsAppInfoProvider(
//            appId: AppInfo.APP_ID,
//            vc: AppInfo.vc,
//            isDebug: EnvManager.shared.isShip(),
//            zpid: zpid,
//            platId: platId,
//            testUploadUrl: testUploadUrl,
//            onlineUploadUrl: onlineUploadUrl,
//            configUrl: configUrl
//        )
//        StatisticsManager.initManager(with: statisticsAppInfoProvider)
//        MarketManager.shared.initManager(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
}
