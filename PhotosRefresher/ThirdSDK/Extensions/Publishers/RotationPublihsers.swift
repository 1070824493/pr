//
//  RotationPublihsers.swift
//  Pods
//
//

import Combine
import UIKit
import Foundation

public extension Publishers {
    
    // MARK: 屏幕方向相关 Publisher
    
    /// 屏幕方向即将变化通知
    /// - 返回值: (原始方向, 目标方向)
    static var willChangeScreenOrientation: AnyPublisher<(from: UIInterfaceOrientation, to: UIInterfaceOrientation), Never> {
        NotificationCenter.default.publisher(for: UIApplication.willChangeStatusBarOrientationNotification)
            .compactMap { notification in
                guard let fromValue = notification.userInfo?[UIApplication.statusBarOrientationUserInfoKey] as? Int,
                      let toValue = notification.userInfo?[UIApplication.statusBarOrientationUserInfoKey] as? Int,
                      let fromOrientation = UIInterfaceOrientation(rawValue: fromValue),
                      let toOrientation = UIInterfaceOrientation(rawValue: toValue) else {
                    return nil
                }
                return (fromOrientation, toOrientation)
            }
            .eraseToAnyPublisher()
    }
    
    /// 屏幕方向变化完成通知
    /// - 返回值: 当前方向
    static var didChangeScreenOrientation: AnyPublisher<UIInterfaceOrientation, Never> {
        NotificationCenter.default.publisher(for: UIApplication.didChangeStatusBarOrientationNotification)
            .compactMap { notification in
                guard let value = notification.userInfo?[UIApplication.statusBarOrientationUserInfoKey] as? Int,
                      let orientation = UIInterfaceOrientation(rawValue: value) else {
                    return nil
                }
                return orientation
            }
            .eraseToAnyPublisher()
    }
    
    /// 屏幕方向变化完整周期 (开始 -> 完成)
    static var screenOrientationCycle: AnyPublisher<OrientationChangeCycle, Never> {
        let willChange = willChangeScreenOrientation
            .map { OrientationChangeCycle(state: .begin, orientation: $0.to) }
        
        let didChange = didChangeScreenOrientation
            .map { OrientationChangeCycle(state: .complete, orientation: $0) }
        
        return Publishers.Merge(willChange, didChange)
            .eraseToAnyPublisher()
    }
    
    // MARK: 状态栏高度相关 Publisher
    
    /// 状态栏帧变化通知
    static var statusBarFrameDidChange: AnyPublisher<CGRect, Never> {
        NotificationCenter.default.publisher(for: UIApplication.didChangeStatusBarFrameNotification)
            .map { _ in
                // 优先从当前活跃的 windowScene 获取状态栏高度
                if let scene = UIApplication.shared.foregroundActiveScene {
                    return scene.statusBarManager?.statusBarFrame ?? .zero
                }
                
                // 兼容旧版本
                return UIApplication.shared.statusBarFrame
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// 状态栏高度变化通知
    static var statusBarHeightDidChange: AnyPublisher<CGFloat, Never> {
        statusBarFrameDidChange
            .map { $0.height }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    // MARK: 设备物理方向改变通知
    
    /// 设备物理方向改变通知
    static var orientationDidChange: AnyPublisher<UIDeviceOrientation, Never> {
        NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .map { _ in UIDevice.current.orientation }
            .eraseToAnyPublisher()
    }
    
}


// MARK: - 辅助类型
public struct OrientationChangeCycle: Equatable {
    public enum State {
        case begin     // 旋转开始
        case complete // 旋转完成
    }
    
    public let state: State
    public let orientation: UIInterfaceOrientation
}

