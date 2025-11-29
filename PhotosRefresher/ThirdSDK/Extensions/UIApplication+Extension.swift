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
    
}
