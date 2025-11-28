//
//  PRHomeTopBar.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI

struct PRHomeTopBar: View {
    let navBarHeight: CGFloat
    let isVip: Bool
    var onTap: () -> Void = {}
    
    @EnvironmentObject var appRouterPath: AppRouterPath

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            HStack(spacing: 8) {
                Image("shezhi-2")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .onTapGesture {
                        onTap()
                    }
                Spacer()
                
            }
            .padding(.bottom, 10)
        }
        .frame(height: navBarHeight)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }
}
