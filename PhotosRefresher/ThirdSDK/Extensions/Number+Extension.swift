//
//  Number+Extension.swift
//  LandscapeAI
//
//  Created by R on 2025/5/6.
//

import Foundation
import UIKit

private var scaleFactor: CGFloat {
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    return UIScreen.main.bounds.width / (isPad ? 768 : 360)
}

public extension BinaryFloatingPoint {
    var fit: CGFloat { CGFloat(self) * scaleFactor }
}

public extension BinaryInteger {
    var fit: CGFloat { CGFloat(self) * scaleFactor }
}
