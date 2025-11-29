//
//  SubscribeNormalPage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import SwiftUI

struct PRSubscribeNormalPage: View {
    
    @EnvironmentObject var viewModel: PRSubscribeViewModel
    
    var body: some View {
        ZStack {
            //最底层, 背景和图片层
            VStack {
                Image("subscribe_normal_top_bg")
                    .resizable()
                    .scaledToFit()
                    .frame(width: kScreenWidth)
                Spacer()
            }
            
            //中间层, 业务展示层
            ScrollView {
                centerBizViewLayer
            }
            
            //最顶层, 顶部Bar和底部Bar
            VStack {
                topBanner
                Spacer()
                bottomButtomView
            }
            
        }
        .ignoresSafeArea()
        
        
    }
    
    var centerBizViewLayer: some View {
        VStack(spacing: 0) {
            Image("ic_sub_normal_top_bg")
                .resizable()
                .frame(width: 290.fit, height: 305.fit)
            
            Text("No Limit To Clean your Storage")
                .font(.system(size: 28.fit, weight: .bold))
                .foregroundColor(Color.hexColor(0x141414))
                .minimumScaleFactor(0.9)
            
            Text("Get rid of what you don't need")
                .font(.system(size: 16.fit, weight: .regular))
                .foregroundColor(Color.hexColor(0x666666))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 8)
            
            let items = Array(viewModel.packageList.prefix(2))

            VStack(spacing: 12) {
                ForEach(items, id: \.skuId) { item in
                    PRSubscribeNormalCellView(item: item)
                }
            }
            .padding(.top, 55)
            .overlay(alignment: .topTrailing, content: {
                if !items.isEmpty {
                    PRSubscribeRandomBubble()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: 12 + 16)
                }
            })
            
        }
        .padding(.horizontal, 16)
        .padding(.top, getStatusBarHeight())
    }
    
    var topBanner: some View {
        HStack {
            Button {
                viewModel.back(false)
            } label: {
                Image("nav_icon_return")
                    .resizable()
                    .frame(width: 32, height: 32)
            }

            Spacer()
            
            Button {
                viewModel.restore()
            } label: {
                Text("Restore")
                    .font(.system(size: 12.fit, weight: .regular))
                    .foregroundColor(Color.white)
                    .frame(height: 28)
                    .padding(.horizontal, 12)
                    .background{
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.6))
                    }
                    
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, getStatusBarHeight() + 8)
    }
    
    var bottomButtomView: some View {
        VStack(spacing: 8.5) {
            PRThemeButton(title: "Continue", type: .subscribe) {
                Task {
                    await viewModel.purchase()
                }
            }
            
            HStack {
                HStack {
                    Text("Privary")
                        .font(.system(size: 12.fit, weight: .regular))
                        .foregroundColor(Color.hexColor(0x141414).opacity(0.24))
                        .onTapGesture {
                            viewModel.openUrl(WebUrl.privatePolicy.fullPath)
                        }
                    Text("|")
                        .font(.system(size: 12.fit, weight: .regular))
                        .foregroundColor(Color.hexColor(0x141414).opacity(0.24))
                    Text("Terms")
                        .font(.system(size: 12.fit, weight: .regular))
                        .foregroundColor(Color.hexColor(0x141414).opacity(0.24))
                        .onTapGesture {
                            viewModel.openUrl(WebUrl.terms.fullPath)
                        }
                }
                
                Spacer()
                
                Text("Cancel Anytime")
                    .font(.system(size: 12.fit, weight: .medium))
                    .foregroundColor(Color.hexColor(0x141414).opacity(0.24))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, getBottomSafeAreaHeight() + 8)
    }
}

#Preview {
    PRSubscribeNormalPage()
}

