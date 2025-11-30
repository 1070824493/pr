import SwiftUI
import UIKit

class PRGlobalOverlay {
    static let shared = PRGlobalOverlay()
    private var overlayWindow: UIWindow?
    public var displayHUDOverlay: Bool = false
    
    private func getCurrentWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    enum ShowAnimation {
        case instant
        case slideFromRight
        case slideFromBottom
    }

    enum HideAnimation {
        case fadeOut
        case slideToLeft
        case slideToTop
        case instantRemove
    }

    /// 在最顶层显示自定义 SwiftUI 视图
    func show<V: View>(
        @ViewBuilder body: () -> V,
        level: UIWindow.Level = .alert + 1,
        showAnimation: ShowAnimation = .instant,
        animationDuration: TimeInterval = 0.15
    ) {
        guard let scene = getCurrentWindowScene() else { return }

        let controller = UIHostingController(rootView: ZStack { body().ignoresSafeArea() })
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false

        let overlay = UIWindow(windowScene: scene)
        overlay.frame = UIScreen.main.bounds
        overlay.windowLevel = level
        overlay.backgroundColor = .clear
        overlay.isOpaque = false
        overlay.rootViewController = controller
        overlay.isHidden = false

        self.overlayWindow = overlay

        switch showAnimation {
        case .instant:
            controller.view.transform = .identity
            controller.view.alpha = 1.0
            
        case .slideFromRight:
            let offset = overlay.bounds.width
            controller.view.transform = CGAffineTransform(translationX: offset, y: 0)
            controller.view.alpha = 1.0
            UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseOut]) {
                controller.view.transform = .identity
            }
            
        case .slideFromBottom:
            let offset = overlay.bounds.height
            controller.view.transform = CGAffineTransform(translationX: 0, y: offset)
            controller.view.alpha = 1.0
            UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseOut]) {
                controller.view.transform = .identity
            }
        }
    }

    /// 隐藏浮层视图
    func hide(hideAnimation: HideAnimation = .fadeOut,
              animationDuration: TimeInterval = 0.22,
              isImmediate: Bool = false) {
        guard let overlay = overlayWindow, let rootView = overlay.rootViewController?.view else { return }
        let screenWidth = overlay.bounds.width
        let screenHeight = overlay.bounds.height

        if isImmediate || hideAnimation == .instantRemove {
            releaseOverlay(overlay)
            return
        }

        switch hideAnimation {
        case .fadeOut:
            UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseIn]) {
                rootView.alpha = 0.0
            } completion: { _ in
                self.releaseOverlay(overlay)
            }
            
        case .slideToLeft:
            UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseIn]) {
                rootView.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            } completion: { _ in
                self.releaseOverlay(overlay)
            }
            
        case .slideToTop:
            UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseIn]) {
                rootView.transform = CGAffineTransform(translationX: 0, y: -screenHeight)
            } completion: { _ in
                self.releaseOverlay(overlay)
            }
            
        case .instantRemove:
            releaseOverlay(overlay)
        }
    }

    /// 释放浮层资源
    private func releaseOverlay(_ overlay: UIWindow) {
        overlay.isHidden = true
        overlay.rootViewController = nil
        overlay.transform = .identity
        self.overlayWindow = nil
    }

    /// 立即关闭
    func hide(isImmediate: Bool) {
        if isImmediate, let overlay = overlayWindow {
            releaseOverlay(overlay)
        } else {
            hide()
        }
    }

    var isDisplaying: Bool { overlayWindow != nil }
}