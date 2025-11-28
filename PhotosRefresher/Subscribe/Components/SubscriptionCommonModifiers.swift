//
//  SubscriptionCommonModifiers.swift
//  Dialogo
//
//  
//

import SwiftUI

struct ScanEffect: ViewModifier {
    let clipRadius: CGFloat
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: clipRadius)
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                .blur(radius: 1)
                .opacity(0.8)
                .blendMode(.plusLighter)
        )
    }
}


struct AutoVibrationModifier: ViewModifier {
    let interval: TimeInterval
    let vibrationStyle: VibrationStyle
    
    enum VibrationStyle {
        case light, medium, heavy, success, error, warning
    }
    
    @State private var timer: Timer?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            performVibration()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func performVibration() {
        switch vibrationStyle {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
}

extension View {
    func autoVibration(interval: TimeInterval = 3.0, style: AutoVibrationModifier.VibrationStyle = .medium) -> some View {
        self.modifier(AutoVibrationModifier(interval: interval, vibrationStyle: style))
    }
}
