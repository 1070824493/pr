//
//  LaunchViewModel.swift

//
//

import Combine


class PRAppViewModel: ObservableObject {
    
    @Published var launchState: LaunchState? = nil
    
    //必须播放一次启动动画后才能进入首页
    @Published var launchPlayFinished: Bool = false
    
    @Published var isFirstOpen = false
    
    var showSubscriptionViewInMainTabView = true
    
    private var tag = "PRAppViewModel"
    
    private var initialized = false
    
    private var configLoadTask: Task<Bool, Never>?
    
    private var configRequestTimeout: TimeInterval = 5.0

    func initRequest(_ hasConfig: Bool = true) async {
        let couldInit = await MainActor.run {
            if !PRRequestHandlerObserver.shared.isReachable {
                return false
            }
            
            if initialized {
                return false
            }
            initialized = true
            return true
        }
        if !couldInit {
            return
        }
        
        await withTaskGroup(of: Any.self) { group in
            if hasConfig {
                group.addTask {
                    await self.requestConfig()
                }
            }
            
            group.addTask {
                await self.requestUserInfo()
            }
            
            group.addTask {
                await self.requestProducts()
            }
        }
    }

    @MainActor
    func doCheckBeforeSetUpView() async -> Bool {
        // 拆到 idfaPage
//        defer {
//            PermissionManager.canShowIDFA = true
//        }
        
        if launchState != nil {
            return false
        }
        
        // 本地有缓存的配置信息：直接使用配置信息
//        if let _ = ConfigManager.shared.appConfig {
//            return true
//        }
        
        // 非新安装首次启动，且没网，直接进入
        if PRAppInfo.lanuchType != .newInstall,
           !PRRequestHandlerObserver.shared.isReachable {
            return true
        }
        
        // 有网直接请求&超时
        if PRRequestHandlerObserver.shared.isReachable {
            configLoadTask?.cancel()
            configLoadTask = nil
            await self.checkProductData()// 调商品列表
            return true
        } else {
            if configLoadTask != nil {
                return false
            }
            
            configLoadTask = Task {[weak self] in
                try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
                guard !Task.isCancelled else {
                    return false
                }
//                await self?.checkConfig()
                await self?.checkProductData()
                return true
            }
            let result = await configLoadTask?.value
            return result ?? false
        }
    }
    
    func checkProductData() async {
        await withTaskGroup(of: Void.self) { group in
            if !PRUserManager.shared.checkVipEligibility() {
                group.addTask {
                    await withTaskCancellationHandler(
                        operation: {
                            await self.race(
                                {
                                    print("checkConfig 6")
                                    await self.requestProducts()
                                    print("checkConfig 7")
                                },
                                {
                                    print("checkConfig 8")
                                    try? await Task.sleep(for: .seconds(self.configRequestTimeout))
                                    print("checkConfig 9")
                                }
                            )
                        },
                        onCancel: {
                            
                        }
                    )
                }
            }
        }
    }

    // 自定义 race 方法（只等待一个任务完成）
    private func race<T>(
        _ first: @escaping @Sendable () async -> T,
        _ second: @escaping @Sendable () async -> T
    ) async -> T {
        await withTaskGroup(of: T.self) { group in
            group.addTask {
                await first()
            }
            group.addTask {
                await second()
            }
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func requestConfig() async {
        let _ = await PRConfigurationManager.instance.updateConfiguration()
    }
    
    private func requestUserInfo() async {
        let _ = await PRUserManager.shared.synchronizeUserInfo()
    }
    
    private func requestProducts() async {
        let _ = await PRProductManager.shared.refreshPackageList(PRSubscribeListRequestModel(source: PaySource.guided.rawValue, scene: PayScene.normal.rawValue))

    }
    
}
