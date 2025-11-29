//
//  NetworkObserver.swift
//

//

import CoreTelephony
import Alamofire

open class PRRequestHandlerObserver: ObservableObject {
    
    public static let shared = PRRequestHandlerObserver()
    
    private init() {}

    open var isReachable: Bool {
        get {
            self.networkReachabilityManager?.isReachable ?? true
        }
    }
    
    @Published public var isReachablePublished = false
    
    public let networkReachabilityManager = NetworkReachabilityManager.default
    
    public func startListening(block: ((Bool) -> Void)? = nil) {
        self.networkReachabilityManager?.startListening(onUpdatePerforming: { [weak self] status in
            switch status {
            case .notReachable:
                print("[NetStatus]:Temporarily no internet connection")
                self?.isReachablePublished = false
                block?(false)
            case .reachable(.ethernetOrWiFi):
                print("[NetStatus]:ethernet or wifi")
                self?.isReachablePublished = true
                block?(true)
            case .reachable(.cellular):
                print("[NetStatus]:Cellular Data")
                self?.isReachablePublished = true
                block?(true)
            case .unknown:
                print("[NetStatus]:network status unknown")
                self?.isReachablePublished = false
                block?(false)
            }
        })
    }
    
    public func stopListening() {
        self.networkReachabilityManager?.stopListening()
    }
    
}
