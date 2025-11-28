//
//  SubscriptionContainerView.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscriptionContainerView: View {
    var variant: PaywallVariant = .classicA
    let paySource: PaySource
    var onDismiss: ((_ isSuc: Bool) -> Void)?

    init(paySource: PaySource = .guided,
         onDismiss: ((_ isSuc: Bool) -> Void)? = nil) {
        if let appConfig = ConfigManager.shared.appConfig {
            self.variant = appConfig.paywallVariant
        }
        self.paySource = paySource
        self.onDismiss = onDismiss
    }

    var body: some View {
        switch variant {
        case .classicA:
            CUSubscriptionHomePlanAView(paySource: paySource, onDismiss: onDismiss)
        
        }
    }
}

