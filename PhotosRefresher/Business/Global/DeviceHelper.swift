//
//  DeviceHelper.swift

//
//  Created by R on 2025/4/9.
//

import UIKit

enum DeviceHelper {
    static var safeAreaInsets: UIEdgeInsets {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow })?.safeAreaInsets ?? .zero
    }
}
