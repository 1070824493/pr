//
//  ConfigManager.swift

//
//



class ConfigManager: ObservableObject {
    
    public static let shared = ConfigManager()
    
    @Published var appConfig: AppConfig? = nil
    
    private let filePath: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isLoopGetVipStatus = false
    
    private let saveQueue = DispatchQueue(label: "PR.configs.queue")
    
    private init() {
        do {
            filePath = try FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: false).appendingPathComponent("app_configs")
            _ = self.loadCache(file: filePath)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func refreshConfig() async -> Bool {
        do {
            let res: PRCommonResponse<AppConfig> = try await PRRequestHandlerManager.shared.PRrequest(url: ApiConstants.photosrefresher_init_config, method: .get)
            if !res.succeed() {
                return false
            }
            
            await MainActor.run {
                self.appConfig = res.data
            }
            save()
            return true
        } catch {
            return false
        }
    }
     
    
    private func loadCache(file: URL) -> Bool {
        if let data = try? Data(contentsOf: file) {
            decoder.dataDecodingStrategy = .base64
            do {
                let savedData = try decoder.decode(AppConfig.self, from: data)
                self.appConfig = savedData
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    private func save() {
        saveQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            do {
                let savedData = self.appConfig
                let data = try self.encoder.encode(savedData)
                try data.write(to: self.filePath, options: .atomicWrite)
            } catch {
                print("Error while saving userinfo: \(error.localizedDescription)")
            }
            self.encoder.dataEncodingStrategy = .base64
        }
    }
    
}

extension ConfigManager {
    var is120Default: Bool {
        true
    }
}
