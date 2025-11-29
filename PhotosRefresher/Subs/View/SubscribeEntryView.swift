//
//  SubscriptionEntryView.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscribeEntryView: View {
    
    @StateObject var subscribeVM: SubscribeViewModel
    
    let paySource: PaySource
    var onDismiss: ((_ result: Bool) -> Void)?

    init(paySource: PaySource = .guided,
         onDismiss: ((_ result: Bool) -> Void)? = nil) {
        
        self.paySource = paySource
        self.onDismiss = onDismiss
        _subscribeVM = StateObject(wrappedValue: SubscribeViewModel(paySource: paySource, onDismiss: onDismiss)) 
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

