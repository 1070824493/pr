//
//  AppInfo.swift

//
//

import UIKit


class AppInfo: DynamicCommonParamsProvider {
    
    enum LaunchType {
        case unknown        // 未知
        case newInstall     // 新安装
        case upgrade        // 覆盖安装
        case normal         // 普通冷启动
    }
    
    public static var lastVC: Int? {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    public static var lanuchType: LaunchType = .unknown
    
    public static let APP_ID = "photosrefresher"

    public static let vc = 100
    
    public static var envName = "ez2"
    
    public static let scheme = "PR://"
    
    public static var encodeCuid = ""
    
    public static let reviewUrl = ""
    
    private static var idfv = ""
    
    public static var staticCommonParams: [String: Any] = {
        return [
            "os": "ios",
            "osName": DeviceUtils.getOSName(),
            "iOSVersion": DeviceUtils.getSystemVersion(),
            "deviceType": DeviceUtils.getDeviceType().rawValue,
            "vcname": getVCName(),
            "shortname": buildVersion(),
            "appId": APP_ID,
            "vc": vc,
            "cuid": getCuid(),
        ]
    }()
    
    public static func getCuid() -> String {
        return CommonAICuid.sharedInstance().getDeviceADID()
    }
    
    public static func getVCName() -> String {
        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return versionName ?? ""
    }
    
    public static func buildVersion() -> String {
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return buildVersion ?? ""
    }
    
    public static func getBundleId() -> String {
        let bundleID = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
        return bundleID ?? ""
    }

    public static func getIDFV() -> String {
        if !idfv.isEmpty {
            return idfv
        }
        idfv = UIDevice.current.identifierForVendor?.uuidString ?? "0"
        return idfv
    }
    
    public static func getDynamicCommonParams() -> [String: Any] {
        return [
            "systemLanguageCode": AppLocalizationManager.shared.getSystemLanguage(),
            "idfa": IdfaUtils.shared.getIdfaSync(),
            "idfv": getIDFV(),
            "appInstanceId": MarketManager.shared.getFirebaseClientId(),
            "firebaseId": MarketManager.shared.getFirebaseClientId(),
            "anonId": MarketManager.shared.getFacebookClientId(),
            "appsFlyerId": MarketManager.shared.getAppsFlyerClientId(),
        ]
    }
    
    public static func getWebDynamicCommonParams() -> [String: Any] {
        return [
            "systemLanguageCode": AppLocalizationManager.shared.getSystemLanguage()
        ]
    }
    
    public static func getEncodeCuid()-> String {
        if !encodeCuid.isEmpty {
            return encodeCuid
        }
        
        let cuid = getCuid()
//        encodeCuid = ZYBCommunicationTool.format2String(with:cuid, string:"vVkiD!@9vaXB0INQ")
        return encodeCuid
    }
    
}

func createWebUrlWithCommonParameters(urlString: String, querys: [String: Any]? = nil) -> URL? {
    guard let url = URL(string: urlString) else {
        return URL(string: urlString)
    }
    
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return  nil}
    let dynamicCommonParams = AppInfo.getWebDynamicCommonParams()
    var parameters = AppInfo.staticCommonParams.merging(dynamicCommonParams) { (current, new) in new }
    if let extParams = querys {
        parameters.merge(extParams) { (current, new) in new }
    }
    
    let parametersArr = convertDictionaryToSortedArray(parameters)
    let queryItems = parametersArr.map { (key, value) -> URLQueryItem in
        URLQueryItem(name: key, value: "\(value)")
    }
    
    urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems
    return urlComponents.url
}
