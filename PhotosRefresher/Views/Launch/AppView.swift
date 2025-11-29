//
//  LaunchView.swift

//
//  Created by R on 2025/4/8.
//

import SwiftUI


enum LaunchState {
    case guide
    case subscription
    case main
}

struct AppView: View {
    @EnvironmentObject var appUserDefaults: AppUserPreferences
    @EnvironmentObject var ConfigManager: ConfigManager
    @EnvironmentObject var networkObserver: NetworkObserver
    
    @StateObject var viewModel = AppViewModel()
    
    private var tag = "AppView"

    var body: some View {
        ZStack {
            if let launchState = viewModel.launchState, viewModel.launchPlayFinished {
                switch launchState {
                case .guide:
                    guideView
                case .subscription:
                    SubscribeEntryView(paySource: viewModel.isFirstOpen ? .coldOpen : .guided) {isSuc in
                        viewModel.launchState = .main
                    }
                case .main:
                    MainTabView(showSubscriptionView: viewModel.showSubscriptionViewInMainTabView)
                }
            }else{
                LaunchView()
                    .id(tag)
                    .environmentObject(viewModel)
            }
        }
        .task(preload)
        .onAppear(perform: handleAppear)
        .onChange(of: networkObserver.isReachablePublished, perform: handleNetworkChanged)
    }
    
    var guideView: some View {
        PRGuidePage {
//            if UserManager.shared.isVip() {
                viewModel.launchState = .main
//            } else {
//                viewModel.launchState = .subscription
//            }
            appUserDefaults.hasFinishGuide = true
        }
    }
    
    @Sendable func preload() async {
        printWithTag(tag: tag, "preload")
        await viewModel.initRequest()
    }
    
    func handleAppear() {
        initLanuchType()
        
        Task {
            let canGo = await viewModel.doCheckBeforeSetUpView()
            if canGo {
                setupView()
            }
            MarketManager.shared.uploadInstallEvent()
        }
    }
    
    private func initLanuchType() {
        
        viewModel.isFirstOpen = appUserDefaults.hasFinishGuide
        guard AppInfo.lanuchType == .unknown else {
            return
        }
        
        let lastVC = AppInfo.lastVC
        if !appUserDefaults.hasFinishGuide {
            AppInfo.lanuchType = .newInstall
        } else if lastVC != AppInfo.vc {
            AppInfo.lanuchType = .upgrade
        } else {
            AppInfo.lanuchType = .normal
        }
        AppInfo.lastVC = AppInfo.vc
    }
    
    private func setupView() {
        // 首次先进入引导页
        if AppInfo.lanuchType == .newInstall {
            viewModel.launchState = .guide
            return
        }
        // 其它先进入订阅页
        if !UserManager.shared.isVip() {
            if AppInfo.lanuchType != .newInstall, ProductManager.shared.packageList().count > 0 {
                viewModel.launchState = .subscription
                return
            }
        }
        // 如果是会员 直接进首页
        viewModel.launchState = .main
    }
    
    private func handleNetworkChanged(_ newReachable: Bool) {
        if newReachable {
            Task {
                let canGo = await viewModel.doCheckBeforeSetUpView()
                if canGo {
                    setupView()
                }
                await viewModel.initRequest()
            }
        }
    }
    
}


#Preview {
    LaunchView()
        .withEnvironments()
}
