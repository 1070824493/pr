//
//  UserManager.swift

//
//



class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var userInfo: UserData? = nil
    
    private let filePath: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isLoopGetVipStatus = false
    
    private let saveQueue = DispatchQueue(label: "PR.userinfo.queue")
    
    private init() {
        do {
            filePath = try FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: false).appendingPathComponent("user_info")
            _ = self.loadCache(file: filePath)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func isVip() -> Bool {
        return userInfo?.vipStatus == 1
    }
    
    func isSubscripting() -> Bool {
        return userInfo?.vipSubStatus == 1
    }
    
    func getUserInfoAsync() async -> UserData? {
        if userInfo != nil {
            return userInfo
        }
        
        let _ = await refreshUserInfo()
        return userInfo
    }
    
    func refreshUserInfo() async -> Bool {
        do {
            let res: CommonResponse<UserData> = try await NetworkManager.shared.request(url: ApiConstants.photosrefresher_user_info, method: .get)
            if !res.succeed() {
                return false
            }
            
            await MainActor.run {
                let userInfo = res.data
                self.userInfo = userInfo
            }
            save()
            return true
        } catch {
            return false
        }
    }
    
    @MainActor
    func loopGetVipStatus() {
        if isLoopGetVipStatus {
            return
        }
        isLoopGetVipStatus = true
        
        Task {
            var attempt = 0
            let maxAttempts = 6
            while attempt < maxAttempts {
                let delay = pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                let succeed = await refreshUserInfo()
                if (succeed) {
                    if isVip() && isSubscripting() {
                        break
                    }
                }
                
                attempt += 1
            }
            
            await MainActor.run {
                isLoopGetVipStatus = false
            }
        }
    }
    
    private func loadCache(file: URL) -> Bool {
        if let data = try? Data(contentsOf: file) {
            decoder.dataDecodingStrategy = .base64
            do {
                let savedData = try decoder.decode(UserData.self, from: data)
                self.userInfo = savedData
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
                let savedData = self.userInfo
                let data = try self.encoder.encode(savedData)
                try data.write(to: self.filePath, options: .atomicWrite)
            } catch {
                print("Error while saving userinfo: \(error.localizedDescription)")
            }
            self.encoder.dataEncodingStrategy = .base64
        }
    }
    
}
