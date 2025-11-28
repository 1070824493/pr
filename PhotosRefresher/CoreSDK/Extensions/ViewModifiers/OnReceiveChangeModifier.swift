//
//  OnReceiveChangeModifier.swift
//  Pods
//
//  类似 iOS 17 支持的 onChange，仅在监听值变化时触发
//

//

import SwiftUI
import Combine

struct OnReceiveChangeModifier<Publisher: Combine.Publisher, Value: Equatable>: ViewModifier where Publisher.Output == Value, Publisher.Failure == Never {
    
    let publisher: Publisher
    let immediately: Bool
    let action: (Value?, Value) -> Void
    
    @State private var oldValue: Value?
    @State private var isInitial = true
    
    func body(content: Content) -> some View {
        content
            .onReceive(publisher) { newValue in
                if isInitial {
                    isInitial = false
                    if !immediately {
                        oldValue = newValue
                        return
                    }
                }
                
                let previousValue = oldValue
                if newValue != oldValue {
                    oldValue = newValue
                    action(previousValue, newValue)
                }
            }
    }
}
