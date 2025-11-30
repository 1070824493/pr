//
//  PRHomeAuthorizationView.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI

struct PRHomeAuthorizationView: View {
    
    @EnvironmentObject private var vm: PRCategoryHomeViewModel
    
    var onTapAllow: () -> Void
    var body: some View {
        VStack(spacing: 12) {

            Image("cleaning_home_noPermission")
                .resizable()
                .frame(width: 64.fit, height: 64.fit)
                .aspectRatio(contentMode: .fit)
                .padding(.top, 31)

            Text("Allow Access to Photos")
                .font(.system(size: 24.fit, weight: .semibold, design: .default))
                .foregroundColor(Color.white)
                .padding(.horizontal, 16)

            Text("The access is needed to find duplicate photos and videos so you can quickly free up storage.")
                .font(.system(size: 16.fit, weight: .regular, design: .default))
                .foregroundColor(Color.hexColor(0x666666))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()
            
            PRThemeButton(title: "Set Access", action: onTapAllow)
                .frame(width: 216.fit)
                .padding(.bottom, 44)
                .padding(.horizontal, 36)
            
        }
    }
}
