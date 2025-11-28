//
//  SubscriptionContinueButton.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscriptionContinueButton: View {
    var title: String
    var color: Color
    @Binding var pulseScale: CGFloat
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.heavy20)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(color)
                .cornerRadius(16)
        }
        .scaleEffect(pulseScale)
        .withScanAnimation(clipRadius: 56)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
        }
    }
}

