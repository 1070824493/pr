//
//  SubscriptionFlowManager.swift
//  Dialogo
//
//  
//

import SwiftUI

@MainActor
final class SubscriptionFlowManager: ObservableObject {

    @Published var exitAlert: ExitAlert?
    @Published var showRetry: Bool = false
    @Published var retryIsFree: Bool = false
    var retryAction: (() -> Void)?

    var purchaseContext: PurchaseTriggerContext = .manual
    var autoPayTask: Task<Void, Never>?
    private var autoPayConsumed = false

    weak var vm: SubscriptionViewModel?
    var paySource: PaySource = .guided
    var onDismiss: ((_ isSuc: Bool) -> Void)?

    init(vm: SubscriptionViewModel, paySource: PaySource, onDismiss: ((_ isSuc: Bool) -> Void)?) {
        self.vm = vm
        self.paySource = paySource
        self.onDismiss = onDismiss
    }

    // MARK: - Entry
    func start() async {
        guard let vm else { return }
        await vm.initPackageList(paySource: paySource, payScene: .normal)
        if vm.isAuditBuild { vm.exitAlertShownOnce = true }
        scheduleAutoPayIfNeeded()
    }
    
    func onAppear() {
        
    }

    func stop() {
        autoPayTask?.cancel()
    }

    // MARK: - Auto Pay
    private func scheduleAutoPayIfNeeded() {
        guard let vm else { return }
        guard !autoPayConsumed,
              vm.isAutoPayEligibleBySource,
              !vm.purchasing,
              !vm.packageList.isEmpty else { return }

        autoPayTask?.cancel()
        let delay = max(1, vm.autoPayDelaySeconds)
        autoPayTask = Task { [weak self, weak vm] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            guard let self, let vm else { return }
            guard !Task.isCancelled,
                  vm.isAutoPayEligibleBySource,
                  !vm.purchasing,
                  !vm.packageList.isEmpty,
                  !autoPayConsumed else { return }

            autoPayConsumed = true
            purchaseContext = .auto
            let pkg = vm.selectedOrFirstPackage
//            StatisticsManager.log(name: "JHP_005", params: ["skuId": pkg?.skuId ?? 0, "type": 7, "subscription": 1])
            await attemptPurchase(package: pkg)
        }
    }

    // MARK: - Exit Alert
    func presentExitAlertIfNeeded() {
        guard let vm else { back(false); return }
        guard vm.isExitAlertEligible else { back(false); return }

        autoPayTask?.cancel()
        autoPayConsumed = true
        Task { @MainActor in vm.markExitAlertShown() }

        let pkg = vm.detainPageProduct
        let isFree = (pkg?.freeDays ?? 0) > 0
//        StatisticsManager.log(name: "JHP_005", params: ["skuId": pkg?.skuId ?? 0, "type": 9, "subscription": 1])

        exitAlert = ExitAlert(
            title: "Boost your phone in 10 seconds",
            message: isFree ? "It's free and easy" : "Not satisfied? Get a full refund",
            okTitle: isFree ? "Try It Free" : "Retry",
            cancelTitle: "Not Now",
            onOK: { [weak self] in
                guard let self else { return }
                self.purchaseContext = .exitDetain
                Task { @MainActor in await self.attemptPurchase(package: pkg) }
            },
            onCancel: { self.back(false) }
        )
    }

    // MARK: - Purchase
    func attemptPurchaseSelected() async {
        await attemptPurchase(package: vm?.selectedOrFirstPackage)
    }

    func attemptPurchase(package: SubscriptionPackage?) async {
        guard let vm, let pkg = package else { return }
        let isFree = (pkg.freeDays > 0) && !vm.isAuditBuild

        let ok = await vm.purchase(paySource: paySource, package: pkg)
        if ok {
            back(true)
        } else if vm.shouldShowFailureAlert(context: purchaseContext) {
            showRetry = false
            retryIsFree = isFree
            retryAction = {
                Task { @MainActor in
                    let pkg = vm.selectedOrFirstPackage
//                    StatisticsManager.log(name: "JHP_005", params: ["skuId": pkg?.skuId ?? 0, "type": 8, "subscription": 1])
                    await self.attemptPurchase(package: pkg)
                }
            }
            showRetry = true
        }
    }

    // MARK: - Exit
    func back(_ isSuc: Bool) {
        stop()
        onDismiss?(isSuc)
    }
}

