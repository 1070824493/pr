//
//  PRGlobalOverlay.swift

//

//

import SwiftUI
import UIKit

final class PRGlobalOverlay {
    static let shared = PRGlobalOverlay()
    private var window: UIWindow?
    public var showOverlayHUDView: Bool = false
    private func activeScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    enum PresentAnimation {
        case none              // 直接显示（默认）
        case rightToLeft       // 从右向左滑入
        case bottomToTop       // 从下到上滑入
    }

    enum DismissAnimation {
        case fade              // 渐隐（默认）
        case leftToRight       // 向右滑出
        case topToBottom       // 向下滑出
        case none              // 立即移除（无动画）
    }

    /// 展示任意 SwiftUI 视图为全局遮罩（在最顶层 UIWindow）
    /// - Parameters:
    ///   - content: 要展示的 SwiftUI 内容
    ///   - windowLevel: 窗口层级
    ///   - animation: 展示动画（默认 .none）
    ///   - duration: 动画时长
    func present<Content: View>(
        @ViewBuilder content: () -> Content,
        windowLevel: UIWindow.Level = .alert + 1,
        animation: PresentAnimation = .none,
        duration: TimeInterval = 0.15
    ) {
        // 若已有 overlay，先移除（立即）
//        dismiss(immediately: true)

        guard let scene = activeScene() else { return }

        // HostingController 包装 content
        let host = UIHostingController(rootView: ZStack { content().ignoresSafeArea() })
        host.view.backgroundColor = .clear
        host.view.isOpaque = false

        let win = UIWindow(windowScene: scene)
        win.frame = UIScreen.main.bounds
        win.windowLevel = .alert + 1
        win.backgroundColor = .clear
        win.isOpaque = false
        win.rootViewController = host
        win.isHidden = false

        self.window = win

        // 根据动画类型设置初始 transform / alpha
        switch animation {
        case .none:
            // 默认：直接显示（不做 transform）
            host.view.transform = .identity
            host.view.alpha = 1.0
        case .rightToLeft:
            let startX = win.bounds.width
            host.view.transform = CGAffineTransform(translationX: startX, y: 0)
            host.view.alpha = 1.0
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: [.curveEaseOut]) {
                host.view.transform = .identity
            }
        case .bottomToTop:
            let startY = win.bounds.height
            host.view.transform = CGAffineTransform(translationX: 0, y: startY)
            host.view.alpha = 1.0
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: [.curveEaseOut]) {
                host.view.transform = .identity
            }
        }
    }

    /// 关闭（支持多种动画）
    /// - Parameters:
    ///   - animation: 关闭时的动画（默认 .fade）
    ///   - duration: 动画时长
    ///   - immediately: 是否立即移除（无动画）
    func dismiss(animation: DismissAnimation = .fade,
                 duration: TimeInterval = 0.22,
                 immediately: Bool = false) {
        guard let win = window, let hostView = win.rootViewController?.view else { return }
        let width = win.bounds.width
        let height = win.bounds.height

        if immediately || animation == .none {
            cleanupWindow(win)
            return
        }

        switch animation {
        case .fade:
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn]) {
                hostView.alpha = 0.0
            } completion: { _ in
                self.cleanupWindow(win)
            }
        case .leftToRight:
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn]) {
                hostView.transform = CGAffineTransform(translationX: width, y: 0)
            } completion: { _ in
                self.cleanupWindow(win)
            }
        case .topToBottom:
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn]) {
                hostView.transform = CGAffineTransform(translationX: 0, y: height)
            } completion: { _ in
                self.cleanupWindow(win)
            }
        case .none:
            cleanupWindow(win)
        }
    }

    /// 立即清理 window 资源（内部方法）
    private func cleanupWindow(_ win: UIWindow) {
        win.isHidden = true
        win.rootViewController = nil
        // 若 host view 有 transform/alpha 被改过，重置以免下次异常
        win.transform = .identity
        self.window = nil
    }

    /// 立即强制移除（对外调用或内部使用）
    func dismiss(immediately: Bool) {
        if immediately {
            if let win = window {
                cleanupWindow(win)
            }
        } else {
            dismiss()
        }
    }

    var isPresenting: Bool { window != nil }
}
