//
//  SubscriptionEntryView.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscriptionEntryView: View {
    
    @StateObject var subscribeVM: SubscriptionViewModel
    
    let paySource: PaySource
    var onDismiss: ((_ result: Bool) -> Void)?

    init(paySource: PaySource = .guided,
         onDismiss: ((_ result: Bool) -> Void)? = nil) {
        
        self.paySource = paySource
        self.onDismiss = onDismiss
        _subscribeVM = StateObject(wrappedValue: SubscriptionViewModel(paySource: paySource, onDismiss: onDismiss)) 
    }

    var body: some View {
        if subscribeVM.isAudit {
            SubscribeNormalPage()
                .environmentObject(subscribeVM)
        }else{
            SubscribeSwitchPage()
                .environmentObject(subscribeVM)
        }
    }
}

