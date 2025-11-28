//
//  SubscriptionNavBar.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscriptionNavBar: View {
    var onBack: () -> Void
    var onRestore: () -> Void
    var delaySeconds: Double = 8
    var paySource: PaySource

    @State private var showBack = true

    var body: some View {
        let topSafe = DeviceHelper.safeAreaInsets.top
        HStack {
            Button(action: onBack) {
                Image("nav_icon_return")
                    .resizable()
                    .frame(width: 32, height: 32)
            }
            .padding(.leading, 16)
            .padding(.top, topSafe+8)
            .opacity(showBack ? 1 : 0)
            .allowsHitTesting(showBack)

            Spacer()

            Button(action: onRestore) {
                Text("Restore")
                    .font(.regular13)
                    .foregroundColor(.gray)
                    .frame(width: 62.fit, height: 32)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .padding(.trailing, 16)
            .padding(.top, topSafe + 8)
        }
        .frame(height: 44 + topSafe)
        .background(Color.clear)
        .task(id: paySource) {
            if paySource == .guided {
                showBack = false
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                withAnimation(.easeInOut) { showBack = true }
            }
        }
    }
}

