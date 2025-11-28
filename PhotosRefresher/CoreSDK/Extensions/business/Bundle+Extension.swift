//
//  Bundle+Extension.swift

//
//  Created by R on 2025/4/15.
//
import Foundation

extension Bundle {
    static var lottie: Bundle? {
        guard let url = Bundle.main.url(forResource: "Lottie", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url: url)
    }
}
