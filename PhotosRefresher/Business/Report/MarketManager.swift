//
//  MarketManager.swift
//  SwiftUITestProject
//
//

//import AppsFlyerLib
//import FirebaseCore
//import FacebookCore
//import FBSDKCoreKit
//import FirebaseAnalytics

//import BuglyPro
import UIKit

class MarketManager {
    
    public static let shared = MarketManager()
    
    public var lastReportInstallVC: Int? {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    private var firebaseClientId = ""       // firebase的客户端ID
    private var facebookClientId = ""       // facebook的客户端ID
    private var appsFlyerClientId = ""      // appsflyer的客户端ID
    
    private init() {
        
    }
    
    func initManager(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
//        initFacebook(application, didFinishLaunchingWithOptions: launchOptions)
//        initFirebase()
//        initAppsFlyerLib()
//        initBugly()
    }
    
    func initFacebook(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
//        ApplicationDelegate.shared.application(
//            application,
//            didFinishLaunchingWithOptions: launchOptions
//        )
    }
    
    func initFirebase() {
//        FirebaseApp.configure()
    }
    
    func initAppsFlyerLib() {
//        AppsFlyerLib.shared().appsFlyerDevKey = "sx9DqKihL5pUsupLUU6HHd"
//        AppsFlyerLib.shared().appleAppID = "6754629561"
//        AppsFlyerLib.shared().customerUserID = AppInfo.getCuid()
//        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
//        #if DEBUG
//        AppsFlyerLib.shared().isDebug = true
//        #endif
    }
    // MARK: - Bugly
//    private func initBugly() {
//        let config = BuglyConfig(appId: BuglyInfoConfig.APP_ID, appKey: BuglyInfoConfig.APP_KEY)
//        config.serverHostType = .buglyPro
//        config.appVersion = AppInfo.buildVersion()
//        config.buildConfig = BuglyBuildConfigRelease
//        config.deviceIdentifier = AppInfo.getCuid()
//        config.userIdentifier = AppInfo.getCuid()
//        let modules = RM_MODULE_ALL as? [String] ?? []
//        Bugly.start(modules, config: config) {
//            print("Bugly 初始化完成")
//        }
//    }
    
    func getFirebaseClientId() -> String {
        if !firebaseClientId.isEmpty {
            return firebaseClientId
        }
        
//        firebaseClientId = Analytics.appInstanceID() ?? ""
        return firebaseClientId
    }
    
    func getFacebookClientId() -> String {
        if !facebookClientId.isEmpty {
            return facebookClientId
        }
//        facebookClientId = AppEvents.shared.anonymousID
        return facebookClientId
    }
    
    func getAppsFlyerClientId() -> String {
        if !appsFlyerClientId.isEmpty {
            return appsFlyerClientId
        }
        
//        if let appsFlyerIdA = AppsFlyerLib.shared().getAppsFlyerUID() as? String,
//           appsFlyerIdA.count > 0 {
//            appsFlyerClientId = appsFlyerIdA
//        }
        return appsFlyerClientId
    }
    
    func reportAppflyer(name: String, params: [String: Any]? = nil) {
//        let reportParams = withCommonParams(params: params)
//        StatisticsManager.log(name: name, params: reportParams)
//        AppsFlyerLib.shared().logEvent(name, withValues: reportParams)
    }
    
    func reportServer(name: String, params: [String: Any]? = nil) {
//        Task {
//            let reportParams = withCommonParams(params: params)
//            StatisticsManager.log(name: name, params: reportParams)
//            let _ = try? await NetworkManager.shared.requestAny(
//                url: ApiConstants.photosrefresher_report_market,
//                method: .post,
//                parameters: [
//                    "eventName": name,
//                    "eventValue": JsonUtils.convertToJson(reportParams),
//                    "version": 2
//                ]
//            )
//        }
    }
    func uploadFaceBook(name: String, params: [String: Any]? = nil) {
//        var convertedParameters: [AppEvents.ParameterName: Any] = [:]
//        params?.forEach { key, value in
//            convertedParameters[AppEvents.ParameterName(rawValue:key)] = value
//        }
//        convertedParameters[AppEvents.ParameterName(rawValue:"cuid")] = CommonAICuid.sharedInstance().getDeviceADID()
//        // 调用 AppEvents.logEvent 方法记录事件
//        AppEvents.shared.logEvent(AppEvents.Name(rawValue:name), parameters: convertedParameters)
    }
    
    func uploadInstallEvent() {
//        Task {
//            let lastVC = lastReportInstallVC ?? 0
//            if lastVC == AppInfo.vc {
//                return
//            }
//            
//            let idfa = await IdfaUtils.shared.requestIdfa()
//            let firebaseClientId = getFirebaseClientId()
//            let facebookClientId = getFacebookClientId()
//            let appsFlyerId = getAppsFlyerClientId()
//            let reportParams = withCommonParams(params: [
//                "idfa": idfa,
//                "appInstanceId": firebaseClientId,
//                "anonId": facebookClientId,
//                "firebaseId": firebaseClientId,
//                "appsFlyerId": appsFlyerId,
//            ])
//            StatisticsManager.log(name: "MARKET_REPORT_INSTALL", params: reportParams)
//            let response = try? await NetworkManager.shared.requestAny(
//                url: ApiConstants.photosrefresher_report_installInfo,
//                method: .post,
//                parameters: reportParams
//            )
//            guard let response = response else {
//                return
//            }
//            
//            let errNo = response["errNo"] as? Int ?? -1
//            if errNo == 0 {
//                lastReportInstallVC = AppInfo.vc
//            }
//        }
    }
    
    private func withCommonParams(params: [String: Any]? = nil) -> [String: Any] {
        var reportParams = [String: Any]()
        if let params = params {
            reportParams.merge(params) { $1 }
        }
        reportParams["af_customer_user_id"] = AppInfo.getCuid()
        return reportParams
    }
    
}
