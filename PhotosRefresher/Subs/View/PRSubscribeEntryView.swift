//
//  SubscriptionEntryView.swift
//  Dialogo
//
//  
//

import SwiftUI

struct PRSubscribeEntryView: View {
    
    @StateObject var subscribeVM: PRSubscribeViewModel
    
    let paySource: PaySource
    var onDismiss: ((_ result: Bool) -> Void)?

    init(paySource: PaySource = .guided,
         onDismiss: ((_ result: Bool) -> Void)? = nil) {
        
        self.paySource = paySource
        self.onDismiss = onDismiss
        _subscribeVM = StateObject(wrappedValue: PRSubscribeViewModel(paySource: paySource, onDismiss: onDismiss)) 
    }

    var body: some View {
        if subscribeVM.isAudit {
            PRSubscribeNormalPage()
                .environmentObject(subscribeVM)
        }else{
            PRSubscribeSwitchPage()
                .environmentObject(subscribeVM)
        }
    }
}

