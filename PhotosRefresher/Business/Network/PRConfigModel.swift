//
//  ConfigModel.swift

//
//

import Foundation


struct PRAppConfig: CodableWithDefault, Equatable {
    
    static var defaultValue: PRAppConfig {
        return PRAppConfig(
            auditSwitch: false,
            paywall: 1
        )
    }
    
    let auditSwitch: Bool
    let paywall: Int
    
}
