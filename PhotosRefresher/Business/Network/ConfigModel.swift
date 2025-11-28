//
//  ConfigModel.swift

//
//

import Foundation


struct AppConfig: CodableWithDefault, Equatable {
    
    static var defaultValue: AppConfig {
        return AppConfig(
            auditSwitch: false,
            paywall: 1
        )
    }
    
    let auditSwitch: Bool
    let paywall: Int
    
}
