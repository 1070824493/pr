//
//  Animation+Extension.swift

//
//

import SwiftUI

extension Animation {
    
    static let sheetAnimation = Animation.spring(response: 0.3, dampingFraction: 0.9)
    
    static let modalAnimation = Animation.easeInOut(duration: 0.3)
    
}
