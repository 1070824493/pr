//
//  CUSubscriptionHomePlanAView.swift
//  Dialogo
//

//

import SwiftUI

struct CUSubscriptionHomePlanAView: View {
    var paySource: PaySource
    var onDismiss: ((_ isSuc: Bool) -> Void)?

    @StateObject private var vm = SubscriptionViewModel()
    @StateObject private var flowManager: SubscriptionFlowManager

    init(paySource: PaySource, onDismiss: ((_ isSuc: Bool) -> Void)? = nil) {
        let viewModel = SubscriptionViewModel()
        _vm = StateObject(wrappedValue: viewModel)
        _flowManager = StateObject(
            wrappedValue: SubscriptionFlowManager(
                vm: viewModel,
                paySource: paySource,
                onDismiss: onDismiss
            )
        )
        self.paySource = paySource
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                SubscriptionTopHalfView()
                SubscriptionProductView(
                    vm: vm,
                    paySource: paySource,
                    onPrivacy: { vm.openUrl(WebUrl.privatePolicy.fullPath) },
                    onTerms: { vm.openUrl(WebUrl.terms.fullPath) },
                    onPurchase: {
                        flowManager.purchaseContext = .manual
                        flowManager.autoPayTask?.cancel()
                        Task { await flowManager.attemptPurchaseSelected() }
                    }
                )
            }

            SubscriptionNavBar(
                onBack: { flowManager.presentExitAlertIfNeeded() },
                onRestore: { vm.restore() },
                paySource: paySource
            )
        }
        .ignoresSafeArea()
        .task { await flowManager.start() }
        .onDisappear { flowManager.stop() }
        .alert(item: $flowManager.exitAlert) { alert in
            Alert(title: Text(alert.title),
                  message: Text(alert.message),
                  primaryButton: .default(Text(alert.okTitle), action: alert.onOK),
                  secondaryButton: .cancel(Text(alert.cancelTitle), action: alert.onCancel))
        }
        .alert("Payment failed", isPresented: $flowManager.showRetry) {
            Button("Not now", role: .cancel) { }
            Button("Try again") { flowManager.retryAction?() }
        } message: {
            Text(flowManager.retryIsFree
                 ? "100% free. No payment now"
                 : "Easily clear. 100% refund if unsatisfied")
        }
        .interactiveDismissDisabled(true)
        .if(!vm.isAuditBuild) { view in
            view.onHomeBottomGestureSwipe { result in
                if result {
                    SoundManager.instance.playSound(isSystemSound: true)
                    GlobalOverlay.shared.present {
                        PRHomeHUDView(type: .onlyText) {
                            GlobalOverlay.shared.dismiss()
                        }
                    }
                }
            }
        }
        .autoVibration(interval: 3.0, style: .heavy)
    }
}
