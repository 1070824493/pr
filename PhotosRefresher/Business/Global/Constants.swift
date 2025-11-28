//
//  Constants.swift

//
//

public struct AppDomainConstants {
    
    public static let business_online_domain = "app.clear.com.ai"
    public static let business_test_domain = "us-\(EnvManager.shared.SHIP_PLACE_HOLDER)-mp.suanshubang.com"
    
    // pay
    public static let unifypay_cleanai_online_domain = "pay.clear.com.ai"
    public static let unifypay_cleanai_test_domain = "unifypay-\(EnvManager.shared.SHIP_PLACE_HOLDER)-mp.suanshubang.com"
}

public struct ApiConstants {
    
    // MARK: - APP
    /// 配置接口
    public static let photosrefresher_init_config = "/aivory/init/config"
    /// 用户信息
    public static let photosrefresher_user_info = "/aivory/user/userinfo"
    /// 用户信息
    
    // MARK: - 订阅
    public static let photosrefresher_subscribe_home = "/aivory/subscribe/home"
    //  签约
    public static let photosrefresher_create_order = "/unifypay/aivoryai/buy/subscribe"
    // 支付凭证上报
    public static let photosrefresher_report_order = "/unifypay/aivoryai/buy/reportApplePay"
    // 投放埋点af上报
    public static let photosrefresher_trace_order = "/unifypay/aivoryai/buy/report"
    // 获取对应商品的skuId 传参是iapId
    public static let photosrefresher_product_getProductInfo = "/aivory/product/getProductInfo"
    
    // MARK: - Chat
    /// 聊天
    public static let photosrefresher_chat_ask = "/aivory/chat/ask"
    
    // MARK: - 投放
    /// 安装信息上报
    public static let photosrefresher_report_installInfo = "/aivory/general/installInfo"
    /// 投放点位上报
    public static let photosrefresher_report_market = "/aivory/general/marketReport"
    
}

public enum WebUrl: String {
    
    // 隐私协议
    case privatePolicy = "https://sites.google.com/view/tn3-ai/privacy-policy"
    // 服务条款
    case terms = "https://sites.google.com/view/tn3-ai/terms-of-use"
        
    var fullPath: String {
        if rawValue.starts(with: "http") || rawValue.starts(with: "file") {
            return rawValue
        }
        
        guard let bundlePath = Bundle.main.path(forResource: "PRFeSource", ofType: "bundle") else {
            return rawValue
        }
        return "file://" + bundlePath.withoutSuffix() + rawValue
    }
    
}

public struct HybridActionConstants {
    
    public struct Common {
        
//        // 打开web页
//        public static let openWindow = "openWindow"
//        
//        // 关闭web页
//        public static let exitWindow = "exit"
//
//        // 打开订阅页
//        public static let showSubscriptionView = "showSubscriptionView"
//        
//        // 打开通用弹窗
//        public static let showCommonModal = "showCommonModal"
//        
//        // 获取用户信息
//        public static let getUserInfo = "getUserInfo"
        
    }
    
}

public struct MarkerReportEvent {
    
    // 订阅页曝光
    public static let subscription_page_show = "af_subscribe_show"
    
    // 点击订阅按钮
    public static let subscription_btn_click = "initiatecheckout"
    
    // 使用核心功能
    public static let all_function_used = "all_function_used"
    
}


//public struct BuglyInfoConfig {
//    public static let APP_ID = "17609f03d0"
//    public static let APP_KEY = "6b164961-dc6e-4dbc-bcd6-c37332b5f3d0"
//}
