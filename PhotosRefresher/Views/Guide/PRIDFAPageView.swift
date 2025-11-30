//
//  DLIDFAPageView.swift

//

//

import SwiftUI

struct PRIDFAPageView: View {
    
    @EnvironmentObject var viewModel: PRGuideViewModel
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Image("guide_idfa_top")
                .resizable()
                .frame(width: 56.fit, height: 56.fit)
                .padding(.top, 101.5.fit)
            Text("We do not use your personal information, you can safely allow this.")
                .font(.system(size: 15.fit, weight: .bold))
                .foregroundColor(Color.hexColor(0x141414))
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Image("guide_idfa_arrow")
                .resizable()
                .frame(width: 24.fit, height: 24.fit)
                .padding(.bottom, 72.fit)
                .offset(y: isAnimating ? -10 : 10) // 上下移动范围
                .animation(
                    Animation.easeInOut(duration: 0.8) // 动画时长
                        .repeatForever(autoreverses: true), // 无限循环且自动反向
                    value: isAnimating
                            )
            Text("Your privacy will be protected and you can change the settings at any time.")
                .font(.system(size: 15.fit, weight: .bold))
                .foregroundColor(Color.hexColor(0x141414))
                .padding(.bottom, 101.fit)
                .multilineTextAlignment(.center)
        }
        .ignoresSafeArea()
        .padding(.horizontal, 40.fit)
        .onAppear {
            isAnimating = true
            checkIDFA()
        }
    }
    
    func checkIDFA() {
        PRPermissionManager.canShowIDFA = true
        PRPermissionManager.requestTrackingPermission {
            if PRPermissionManager.shared.queryTrackingAuthorizationStatus() != .notDetermined {
                DispatchQueue.main.async {
                    viewModel.next()
                }
            }else{
                delay(0.5) {
                    checkIDFA()
                }
            }
        }
    }
}

#Preview {
    PRIDFAPageView()
}
