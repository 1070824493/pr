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
              color: #000000;
              margin: 0;
              padding: 12px;
            }
            .input-start { margin: 0 0 12px 0; color: #000000; }
            .placeholder { color: #8E8E93; margin: 0 0 8px 0; }
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
          <p class="input-start"><br></p>

          <div class="placeholder">Write your message here</div>

          <div class="note">In order to successfully reply to your email, please do not delete the following content. Thank you!</div>

          <hr class="sep">

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
