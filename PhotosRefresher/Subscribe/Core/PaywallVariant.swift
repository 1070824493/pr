//
//  PaywallVariant.swift
//  Dialogo
//
//  
//

import SwiftUI

// 订阅页协议
protocol SubscriptionPage: View {
    var paySource: PaySource { get }
    var onDismiss: ((_ isSuc: Bool) -> Void)? { get }
}

// 订阅页类型
enum PaywallVariant: Int, Codable, CaseIterable {
    case classicA = 1
//    case classicB = 2
//    case classicC = 3

    // 根据 paywall 数值安全初始化
    static func from(_ rawValue: Int) -> PaywallVariant {
        guard let variant = PaywallVariant(rawValue: rawValue),
              PaywallVariant.allCases.contains(variant)
        else {
            return .classicA
        }
        return variant
    }
}
