//
//  KeyboardPublishers.swift
//  Pods
//
//

import Combine
import Foundation
import UIKit

public extension Publishers {
    /**
     * 键盘高度
     */
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { 
                guard let userInfo = $0.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return CGFloat(0)
                }
                return keyboardFrame.height
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
    
}

