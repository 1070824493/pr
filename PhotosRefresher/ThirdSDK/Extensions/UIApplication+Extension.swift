//
//  UIApplication+Extension.swift
//  OverseasSwiftExtensions
//
//
import UIKit

public extension UIApplication {
    
    // 活跃场景
    var foregroundActiveScene: UIWindowScene? {
        connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first
    }
    
    // 隐藏键盘
    func endEditing() {
        foregroundActiveScene?.windows
            .filter {$0.isKeyWindow}
            .first?.endEditing(true)
    }
    
    func topMostViewController() -> UIViewController? {
        guard let scene = connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        return root.topMostPresented()
    }
    
}

extension UIViewController {
    func topMostPresented() -> UIViewController {
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostPresented() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostPresented() ?? tab
        }
        if let presented = presentedViewController {
            return presented.topMostPresented()
        }
        return self
    }
}
