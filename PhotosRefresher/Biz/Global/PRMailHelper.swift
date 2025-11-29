//
//  AppMailHelper.swift

//

//

import MessageUI
import UIKit

final class PRAppMailHelper: NSObject, MFMailComposeViewControllerDelegate {

    static let shared = PRAppMailHelper()
    private override init() {}

    static func presentSupportEmail() {
        guard let presenter = UIApplication.shared.topMostViewController() else { return }

        let email = "mdkauwnc529@yeah.net"
        let subject = "Contact US"

        let appVersion = "\(PRAppInfo.buildVersion()) (\(PRAppInfo.getVCName()))"
        let deviceID   = PRAppInfo.getCuid()
        let deviceInfo = "\(PRDeviceUtils.getDeviceModel()), \(PRDeviceUtils.getSystemVersion())"

        // ====== 改动处：新的 HTML body（首段黑色空段落，placeholder 灰色，强调句独立黑色块） ======
        let htmlBody = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
              font-size:16px;
              line-height:1.6;
              color: #000000; /* 默认黑色（首段用于输入） */
              margin: 0;
              padding: 12px;
            }
            .input-start { margin: 0 0 12px 0; color: #000000; } /* 黑色空段落，放光标 */
            .placeholder { color: #8E8E93; margin: 0 0 8px 0; }   /* 灰色说明 */
            .note {
              display:inline-block;
              background:#F5F5F7;
              color:#000000;
              padding:8px 12px;
              border-radius:10px;
              font-weight:600;
              margin: 8px 0;
            }
            .meta { color:#8E8E93; margin-top:12px; font-size:14px; }
            hr.sep { border:none; border-top:1px solid #E5E5EA; margin:12px 0; }
          </style>
        </head>
        <body>
          <!-- 1. 首段：黑色空段落。光标通常会落在这里，用户输入为黑色 -->
          <p class="input-start"><br></p>

          <!-- 2. 灰色占位/提示（在首段下面，不影响输入颜色） -->
          <div class="placeholder">Write your message here</div>

          <!-- 3. 强调句：单独的黑色高亮块（不会影响首段颜色） -->
          <div class="note">In order to successfully reply to your email, please do not delete the following content. Thank you!</div>

          <hr class="sep">

          <!-- 4. 元信息：灰色 -->
          <div class="meta">
            <div><strong>App version:</strong> \(appVersion)</div>
            <div><strong>DeviceID:</strong> \(deviceID)</div>
            <div><strong>Device:</strong> \(deviceInfo)</div>
          </div>
        </body>
        </html>
        """
        // ====== end htmlBody ======

        if MFMailComposeViewController.canSendMail() {
            let vc = MFMailComposeViewController()
            vc.mailComposeDelegate = PRAppMailHelper.shared
            vc.setToRecipients([email])
            vc.setSubject(subject)
            vc.setMessageBody(htmlBody, isHTML: true)
            presenter.present(vc, animated: true)
        } else {
            // 回退：mailto（无法设置颜色）
            let bodyText = """
            Write your message here


            In order to successfully reply to your email, please do not delete the following content. Thank you!

            App version: \(appVersion)
            DeviceID: \(deviceID)
            Device: \(deviceInfo)
            """
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedBody = bodyText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
                UIApplication.shared.open(url)
            }
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }
}

// MARK: - 顶层 VC 获取
extension UIApplication {
    func topMostViewController() -> UIViewController? {
        guard let scene = connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        return root.topMostPresented()
    }
}

private extension UIViewController {
    func topMostPresented() -> UIViewController {
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostPresented() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostPresented() ?? tab
        }
        if let presented = presentedViewController {
            return presented.topMostPresented()
        }
        return self
    }
}
