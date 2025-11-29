//
//  MainTabView.swift

//
//

import SwiftUI
import SwiftUIIntrospect


struct MainTabView: View {
    @EnvironmentObject private var uiState: UIState
    @EnvironmentObject private var networkObserver: PRRequestHandlerObserver
    @EnvironmentObject private var appUserDefaults: AppUserPreferences

    var showSubscriptionView: Bool = true
    
    @StateObject private var viewModel = MainTabViewModel()
    @StateObject private var appRouterPath = AppRouterPath()
    @State private var showLaunchPlaceHoder = true
    
    var body: some View {
        ZStack {
//            if showLaunchPlaceHoder && showSubscriptionView {
//                LaunchView()
//                    .zIndex(.infinity)
//            }
            
            realMainTabView
        }
    }
    
    var realMainTabView: some View {
        NavigationStack(path: $appRouterPath.path) {
            ZStack {
                tabView
                                
                customTabBar
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .zIndex(1)
            }
            .background(.white)
            .ignoresSafeArea()
            .statusBarHidden(uiState.hideStatusBar ? true : false)
            .withAppRouter()
            .onAppear(perform: handleAppear)
        }
        .environmentObject(appRouterPath)
    }

    
    var tabView: some View {
        TabView(
            selection: .init(
                get: {
                    uiState.selectedTab
                },
                set: { newTab in
                    updateTab(with: newTab)
                })
        ) {
            ForEach(viewModel.availableTabs) { tab in
                tab.makeContentView(selectedTab: $uiState.selectedTab)
                    .tabItem {
                        EmptyView()
                    }
                    .tag(tab)
            }
        }
        .introspect(.tabView, on: .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26)) { (tabBarController: UITabBarController) in
            initTabBarStyle(tabBarController)
        }
        .padding(0)
    }
    
    var customTabBar: some View {
        ZStack {
            Color.clear
            HStack(spacing: 0) {
                ForEach(viewModel.availableTabs) { tab in
                    Button{
                        uiState.selectedTab = tab
                    } label:{
                        VStack(spacing: 0) {
                            let selected = uiState.selectedTab == tab
                            let iconName = selected ? tab.selectedIcon : tab.unselectedIcon
                            Image(iconName)
                                .resizable()
                                .frame(width: 24.fit, height: 24.fit)
//                                .padding(.top, 8)
                            
                            let color = selected ? Color.white.opacity(0.85) : Color.white.opacity(0.35)
                            let weight = selected ? Font.Weight.bold : Font.Weight.regular
                            Text(tab.title)
                                .foregroundStyle(color)
                                .font(
                                    .system(
                                        size: 10.fit,
                                        weight: weight
                                    )
                                )
//                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: uiState.homefooterHeight)
            .background(Color.white.opacity(0.1))
            .cornerRadius(uiState.homefooterHeight / 2.0)
            .padding(.horizontal, 16)
            .padding(.bottom, getBottomSafeAreaHeight() + 3)
        }
        .frame(height: uiState.homefooterHeight + getBottomSafeAreaHeight())
        .frame(maxWidth: .infinity)
    }
    
    private func updateTab(with newTab: UIState.Tab) {
        #if DEBUG
        print("updateTab newTab = \(newTab)")
        #endif
    }
    
    private func initTabBarStyle(_ tabBarController: UITabBarController) {
        tabBarController.tabBar.isHidden = true
    }
    
    private func handleAppear() {
        showRealMainTabView()
        
    }
    
    private func showRealMainTabView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showLaunchPlaceHoder = false
        }
    }
    
    private func handleLanguageChanged(newLanguageCode: String) {
        
    }
    
}

#Preview {
    MainTabView()
        .withEnvironments()
}
