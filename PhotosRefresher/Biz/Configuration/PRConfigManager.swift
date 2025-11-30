//
//  PRConfigurationManager.swift
//

import Foundation

class PRConfigurationManager: ObservableObject {
    
    public static let instance = PRConfigurationManager()
    
    @Published var configuration: PRAppConfig? = nil
    
    private let configFilePath: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let operationQueue = DispatchQueue(label: "com.app.config.queue")
    
    private init() {
        do {
            configFilePath = try FileManager.default.url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: false).appendingPathComponent("app_configurations")
            _ = loadConfiguration(from: configFilePath)
        } catch {
            fatalError("Failed to initialize AppConfigManager: \(error.localizedDescription)")
        }
    }
    
    /// 异步刷新配置
    func updateConfiguration() async -> Bool {
        do {
            let response: PRCommonResponse<PRAppConfig> = try await PRRequestHandlerManager.shared.PRrequest(
                url: ApiConstants.photosrefresher_init_config,
                method: .get
            )
            
            if !response.succeed() {
                return false
            }
            
            await MainActor.run {
                self.configuration = response.data
            }
            saveConfiguration()
            return true
        } catch {
            print("Failed to update configuration: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从缓存加载配置
    private func loadConfiguration(from file: URL) -> Bool {
        guard let cachedData = try? Data(contentsOf: file) else {
            return false
        }
        
        jsonDecoder.dataDecodingStrategy = .base64
        do {
            let decodedConfig = try jsonDecoder.decode(PRAppConfig.self, from: cachedData)
            self.configuration = decodedConfig
            return true
        } catch {
            print("Failed to decode cached configuration: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 保存配置到本地
    private func saveConfiguration() {
        operationQueue.async { [weak self] in
            guard let self = self, let configToSave = self.configuration else {
                return
            }
            
            do {
                let encodedData = try self.jsonEncoder.encode(configToSave)
                try encodedData.write(to: self.configFilePath, options: .atomicWrite)
            } catch {
                print("Failed to save configuration: \(error.localizedDescription)")
            }
        }
    }
}
