//
//  Functions.swift

//
//

import UIKit
import StoreKit

public func performTaskOnMainThread(_ task: @escaping () -> Void) {
    if Thread.isMainThread {
        task()
    } else {
        DispatchQueue.main.async {
            task()
        }
    }
}

// pt缩放
let kScreenWidth = UIScreen.main.bounds.width
let kScreenHeight = UIScreen.main.bounds.height
public func fitScale(_ point: CGFloat) -> CGFloat {
    let isIPad = DeviceUtils.getDeviceType() == .pad
    return (kScreenWidth / (isIPad ? 768 : 360)) * point;
}

// 获取状态栏的高度
func getStatusBarHeight() -> CGFloat {
    let window = UIApplication.shared.windows.first
    let statusBarHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    return statusBarHeight
}

// 获取底部安全区域的高度
func getBottomSafeAreaHeight() -> CGFloat {
    let window = UIApplication.shared.windows.first
    let bottomSafeAreaHeight = window?.safeAreaInsets.bottom ?? 0
    return bottomSafeAreaHeight
}

// 跳转系统设置里的应用权限页
func gotoAccessSetting() {
    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    }
}

// 打开一个url，https协议的话会唤起默认浏览器
@MainActor
func checkAndOpenUrl(_ url: String) async -> Bool {
    if url.isEmpty {
        return false
    }
    
    if let url = URL(string: url) {
        if UIApplication.shared.canOpenURL(url) {
            return await UIApplication.shared.open(url, options: [:])
        }
    }
    
    return false
}

// 应用内评分
func requestAppReview() -> Bool {
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
        return true
    } else {
        return false
    }
}

// 隐藏键盘
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// 字段转数组
func convertDictionaryToSortedArray(_ dict: [String: Any]) -> [(key: String, value: Any)] {
    let keys = dict.keys.sorted()
    return keys.map {
        let key = "\($0)"
        let value = dict[$0]!
        return (key: key, value: value)
    }
}

// 打印日志
func printWithTag(tag: String, _ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let content = items.map { String(describing: $0) }.joined(separator: separator)
    print("[\(Date.getCurrentZoneTime(timeFormat: TimeFormat.millSecond))][\(tag)] \(content)", terminator: terminator)
    #endif
}


@discardableResult
public func delay(_ duration: TimeInterval, _ block: @escaping (() -> Void)) -> DispatchWorkItem {
    let task = DispatchWorkItem(block: block)
    DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    return task
}
