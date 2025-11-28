//
//  PRPurchaseOverlayHUDView.swift

//

//

import SwiftUI

enum PurchaseHUDType {
    case normal,
         freeTrial,
         notText,
         onlyText
}

struct PRHomeHUDView: View {
    var type: PurchaseHUDType = .notText
    var rotationInterval: TimeInterval = 1.5
    var onDismiss: (() -> Void)? = nil

    @State private var messageIndex: Int = 0
    @State private var rotationTask: Task<Void, Never>? = nil
    @State private var dismissTask: Task<Void, Never>? = nil
    @State private var didStartTasks = false
    
    @State private var lottieOpacity: Double = 1.0
    @State private var textOffset: CGFloat = 0
    @State private var textOpacity: Double = 1.0

    private var messages: [String] {
        switch type {
        case .normal:
            return [
                "Your smart space upgrade starts now",
                "9,863 people started today",
                "You're getting a deal better than 99% of users",
                "Not satisfied? Get a 100% refund"
            ]
        case .freeTrial:
            return [
                "7-day free trial",
                "Wait, don't go...",
                "Start 3 days for free!"
            ]
        case .notText:
            return []
        case .onlyText:
            return [
                "Wait,don't go...",
                "Special offer knocks but once.",
                "Not satisfied?\nGet a 100% refund."
            ]
        }
    }

    private var currentText: String {
        guard !messages.isEmpty else { return "" }
        return messages[messageIndex]
    }

    private var hasLottie: Bool {
        switch type {
        case .onlyText:
            return false
        case .notText:
            return true
        default:
            return true
        }
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            BlurView(style: .systemMaterialDark).ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 12) {
                        if hasLottie {
                            MALottieView(
                                animationName: "HomeLoading/data",
                                loopMode: .loop,
                                speed: 1.0,
                                bundle: .lottie
                            )
                            .frame(width: 100, height: 100)
                            .opacity(lottieOpacity)
                            .animation(.easeInOut(duration: 0.8), value: lottieOpacity)
                        }

                        if currentText.count > 0 {
                            let temoFont = (type == .normal) ? Font.semibold16 : Font.bold24
                            Text(currentText)
                                .id(messageIndex)
                                .font(temoFont)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16.fit)
                                .offset(y: textOffset)
                                .opacity(textOpacity)
                                .animation(.easeInOut(duration: 0.8), value: textOffset)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, hasLottie ? geo.size.height * 0.12 : 0)

                    Spacer()
                }
            }
        }
        .onAppear {
            guard !didStartTasks else { return }
            didStartTasks = true
            startDismissCountdown()
            startRotation()
        }
        .onDisappear {
            rotationTask?.cancel()
            dismissTask?.cancel()
            rotationTask = nil
            dismissTask = nil
            didStartTasks = false
        }
    }

    // MARK: - Tasks
    private func startDismissCountdown() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await MainActor.run {
                GlobalOverlay.shared.dismiss()
            }
        }
    }

    private func startRotation() {
        rotationTask?.cancel()
        guard !messages.isEmpty else { return }

        rotationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(rotationInterval * 1_000_000_000))
                await MainActor.run {
                    let nextIdx = (messageIndex + 1) % messages.count

                    if type == .freeTrial {
                        if nextIdx == 1 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                lottieOpacity = 0
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    textOffset = hasLottie ? -60 : 0
                                }
                            }
                        } else if nextIdx == 0 {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                lottieOpacity = 1
                                textOffset = 0
                            }
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            textOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                textOpacity = 1
                            }
                        }
                    }
                    if type == .onlyText && nextIdx == messages.count - 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            startDismissCountdown()
                        }
                    }

                    messageIndex = nextIdx
                }
            }
        }
    }
}
