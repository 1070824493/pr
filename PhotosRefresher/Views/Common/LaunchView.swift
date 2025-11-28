//
//  LaunchView.swift

//
//

import SwiftUI

struct LaunchView: View {
    
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            
            Image("AppLaunch")
                .resizable()
                .frame(width: 112.5, height: 112.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.hexColor(0x186F6F))
        .ignoresSafeArea(.all)
        .onAppear {
            delay(0.5) {
                //防止异常情况卡启动页,最迟3s标记结束
                appViewModel.launchPlayFinished = true
            }
        }
    }
}

#Preview {
    LaunchView()
}
