//
//  PRUserManager.swift

import Foundation
import Combine

final class PRUserManager: ObservableObject {
    static let shared = PRUserManager()
    
    @Published var currentUser: PRUserData? = nil
    
    private let storagePath: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private var isPollingVipStatus = false
    
    private let persistQueue = DispatchQueue(label: "com.pr.user.persist")
    
    private init() {
        do {
            storagePath = try FileManager.default.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: false).appendingPathComponent("user_info")
            _ = self.fetchCachedData(from: storagePath)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func checkVipEligibility() -> Bool {
        return currentUser?.vipStatus == 1
    }
    
    func checkSubscriptionActive() -> Bool {
        return currentUser?.vipSubStatus == 1
    }
    
    func obtainUserInfoAsync() async -> PRUserData? {
        if currentUser != nil {
            return currentUser
        }
        
        let _ = await synchronizeUserInfo()
        return currentUser
    }
    
    func synchronizeUserInfo() async -> Bool {
        do {
            let res: PRCommonResponse<PRUserData> = try await PRRequestHandlerManager.shared.PRrequest(url: ApiConstants.photosrefresher_user_info, method: .get)
            if !res.succeed() {
                return false
            }
            
            await MainActor.run {
                let fetchedUser = res.data
                self.currentUser = fetchedUser
            }
            persistUserData()
            return true
        } catch {
            return false
        }
    }
    
    @MainActor
    func startPollingVipStatus() {
        if isPollingVipStatus {
            return
        }
        isPollingVipStatus = true
        
        Task {
            var iteration = 0
            let maxIterations = 6
            while iteration < maxIterations {
                let waitTime = pow(2.0, Double(iteration))
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                
                let success = await synchronizeUserInfo()
                if success {
                    if checkVipEligibility() && checkSubscriptionActive() {
                        break
                    }
                }
                
                iteration += 1
            }
            
            await MainActor.run {
                isPollingVipStatus = false
            }
        }
    }
    
    private func fetchCachedData(from: URL) -> Bool {
        if let cachedData = try? Data(contentsOf: from) {
            jsonDecoder.dataDecodingStrategy = .base64
            do {
                let decodedUser = try jsonDecoder.decode(PRUserData.self, from: cachedData)
                self.currentUser = decodedUser
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    private func persistUserData() {
        persistQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            do {
                let userToPersist = self.currentUser
                let encodedData = try self.jsonEncoder.encode(userToPersist)
                try encodedData.write(to: self.storagePath, options: .atomicWrite)
            } catch {
                print("Error while persisting user data: \(error.localizedDescription)")
            }
            self.jsonEncoder.dataEncodingStrategy = .base64
        }
    }
    
}