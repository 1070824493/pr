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

struct PRAppView: View {
    @EnvironmentObject var appUserDefaults: PRAppUserPreferences
    @EnvironmentObject var ConfigManager: PRConfigurationManager
    @EnvironmentObject var networkObserver: PRRequestHandlerObserver
    
    @StateObject var viewModel = PRAppViewModel()
    
    private var tag = "AppView"

    var body: some View {
        ZStack {
            if let launchState = viewModel.launchState, viewModel.launchPlayFinished {
                switch launchState {
                case .guide:
                    guideView
                case .subscription:
                    PRSubscribeEntryView(paySource: viewModel.isFirstOpen ? .coldOpen : .guided) {isSuc in
                        viewModel.launchState = .main
                    }
                case .main:
                    PRTabView(showSubscriptionView: viewModel.showSubscriptionViewInMainTabView)
                }
            }else{
                PRLaunchView()
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
//            if PRUserManager.shared.checkVipEligibility() {
                viewModel.launchState = .main
//            } else {
//                viewModel.launchState = .subscription
//            }
            appUserDefaults.guided = true
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
            PRMarketManager.shared.reportInstall()
        }
    }
    
    private func initLanuchType() {
        
        viewModel.isFirstOpen = appUserDefaults.guided
        guard PRAppInfo.lanuchType == .unknown else {
            return
        }
        
        let lastVC = PRAppInfo.lastVC
        if !appUserDefaults.guided {
            PRAppInfo.lanuchType = .newInstall
        } else if lastVC != PRAppInfo.vc {
            PRAppInfo.lanuchType = .upgrade
        } else {
            PRAppInfo.lanuchType = .normal
        }
        PRAppInfo.lastVC = PRAppInfo.vc
    }
    
    private func setupView() {
        // 首次先进入引导页
        if PRAppInfo.lanuchType == .newInstall {
            viewModel.launchState = .guide
            return
        }
        // 其它先进入订阅页
        if !PRUserManager.shared.checkVipEligibility() {
            if PRAppInfo.lanuchType != .newInstall, PRProductManager.shared.packageList().count > 0 {
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
    PRLaunchView()
        .provideEnivironmentObject()
}
