//
//  EnvManager.swift
//

//

public enum Environment2: Identifiable, Equatable {
 
    case online
    case tips
    case ship(name: String)
    
    public var id: String {
        switch self {
        case .online: return "online"
        case .tips: return "tips"
        case let .ship(name): return "ship"
        }
    }
    
    public var shipName: String {
        switch self {
        case .online, .tips: return ""
        case let .ship(name): return name
        }
    }
    
}

public class PREnvironmentManager {
    
    public static let shared = PREnvironmentManager()
    
    public var currentEnv: Environment2 = .online
    
    public let SHIP_PLACE_HOLDER = "&placeholder&"
    
    private var domainConfigs: [String: (onlineDomain: String, testDomain: String)] = [:]
    
    var cacheEnvName: String? {
        get { UserDefaults.standard.string(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    private init() {}
    
    public func initEnv(domainConfigs: [String: (onlineDomain: String, testDomain: String)], inEnvName: String = "") {
        // 优先用缓存的env，没缓存的话用传入的env
        var useEnvName = self.cacheEnvName ?? ""
        if useEnvName.isEmpty {
            useEnvName = inEnvName
        }
        if useEnvName == "" || useEnvName == Environment2.online.id {
            self.currentEnv = .online
        } else if useEnvName == Environment2.tips.id {
            self.currentEnv = .tips
        } else {
            self.currentEnv = .ship(name: useEnvName)
        }
        
        self.domainConfigs = domainConfigs
    }
    
    public func updateEnv(env: Environment2) {
        switch env {
        case .online, .tips:
            self.cacheEnvName = env.id
        case .ship(let shipName):
            self.cacheEnvName = shipName
        }
    }
    
    public func PRCreateFullRequestUrl(_ url: String) -> String {
        if url.starts(with: "http") {
            return url
        }
        
        let components = url.split(separator: "/")
        guard let firstComponent = components.first else {
            return url
        }
        
        guard let domains = self.domainConfigs[String(firstComponent)] else {
            return url
        }
        
        var domain = ""
        switch currentEnv {
        case .online, .tips:
            domain = domains.onlineDomain
        default:
            domain = domains.testDomain.replacingOccurrences(of: SHIP_PLACE_HOLDER, with: currentEnv.shipName)
        }
        
        return "https://\(domain)\(url)"
    }
    
    public func isShip() -> Bool {
        switch currentEnv {
        case .online, .tips:
            return false
        default:
            return true
        }
    }
    
    public func isTips() -> Bool {
        switch currentEnv {
        case .tips:
            return true
        default:
            return false
        }
    }

}
