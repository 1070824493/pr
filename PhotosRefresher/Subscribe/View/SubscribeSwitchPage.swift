//
//  SubscribeSwitchPage.swift
//  PhotosRefresher
//
//  Created by ty on 2025/11/28.
//

import SwiftUI

struct SubscribeSwitchPage: View {
    
    @State var isDiscountEnable: Bool = true {
        didSet{
            if isDiscountEnable {
                if let skuId = viewModel.packageList.first?.skuId {
                    viewModel.selectedPackageId = skuId
                }
            }else{
                if let skuId = viewModel.packageList.last?.skuId {
                    viewModel.selectedPackageId = skuId
                }
            }
        }
    }
    
    @EnvironmentObject var viewModel: SubscriptionViewModel
    
    var body: some View {
        ZStack {
            //最底层, 背景和图片层
            VStack {
                Image("subscribe_switch_top_bg")
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
            Image("ic_sub_switch_top_bg")
                .resizable()
                .frame(width: 281.fit, height: 244.fit)
            
            Text("Get Unlimited Cleaning")
                .font(.system(size: 28.fit, weight: .bold))
                .foregroundColor(Color.hexColor(0x141414))
            
            Text("Accessible anytime, anywhere for a faster, lighter iPhone.")
                .font(.system(size: 16.fit, weight: .regular))
                .foregroundColor(Color.hexColor(0x666666))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Photos Refresher PRO")
                    .font(.system(size: 16.fit, weight: .bold))
                    .foregroundColor(Color.hexColor(0x141414))
                Text("Unlimited Clean your Storage")
                    .font(.system(size: 14.fit, weight: .regular))
                    .foregroundColor(Color.hexColor(0x666666))
                if let selectPackage = viewModel.selectPackage {
                    Text(viewModel.switchTitle(selectPackage))
                        .font(.system(size: 14.fit, weight: .regular))
                        .foregroundColor(Color.hexColor(0x666666))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.hexColor(0xF0F0F0))
            )
            .padding(.top, 16)
            
            HStack {
                Text("Discont Enabled")
                    .font(.system(size: 14.fit, weight: .regular))
                    .foregroundColor(Color.hexColor(0x141414))
                
                Spacer()
                
                Toggle("", isOn: Binding(get: {
                    isDiscountEnable
                }, set: { value in
                    isDiscountEnable = value
                }))
                    .tint(Color.hexColor(0x00D185))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.hexColor(0xF0F0F0))
            )
            .padding(.top, 12)
            
            HStack {
                VStack(spacing: 0) {
                    Spacer().frame(height: 6)
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundColor(Color.hexColor(0x141414))
                    Rectangle()
                        .frame(width: 0.5, height: 24)
                        .foregroundColor(Color.hexColor(0x141414))
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundColor(Color.hexColor(0x141414))
                    Spacer().frame(height: 6)
                }
                
                if let selectPackage = viewModel.selectPackage {
                    VStack {
                        HStack(spacing: 0) {
                            Text("Due Today")
                                .font(.system(size: 14.fit, weight: .regular))
                                .foregroundColor(Color.hexColor(0x141414))
                            
                            Spacer()
                            
                            if isDiscountEnable {                            
                                Text("First week ")
                                    .font(.system(size: 14.fit, weight: .bold))
                                    .foregroundColor(Color.hexColor(0x00D185))
                            }
                            
                            Text(String(format: "$%.2f", selectPackage.priceFirstShow))
                                .font(.system(size: 14.fit, weight: .bold))
                                .foregroundColor(Color.hexColor(0x141414))
                        }
                        Spacer()
                        HStack {
                            
                            Text("Due \(Date.getDateStringAfter(components: selectPackage.expireComponents))")
                                .font(.system(size: 14.fit, weight: .regular))
                                .foregroundColor(Color.hexColor(0x141414))
                            
                            Spacer()
                            Text(String(format: "$%.2f", selectPackage.priceSaleReal))
                                .font(.system(size: 14.fit, weight: .bold))
                                .foregroundColor(Color.hexColor(0x141414))
                        }
                    }
                }
                
            }
            .padding(.top, 12)
            
        }
        .padding(.horizontal, 16)
        .padding(.top, getStatusBarHeight())
    }
    
    var topBanner: some View {
        HStack {
            Button {
                viewModel.back(false)
            } label: {
                Image("ic_normal_close")
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
                            .fill(Color.black.opacity(0.2))
                    }
                    
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, getStatusBarHeight() + 8)
    }
    
    var bottomButtomView: some View {
        VStack(spacing: 8.5) {
            ThemeButton(title: "Start Plan", type: .subscribe) {
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
                
                HStack(spacing: 3) {
                    Image("ic_bottom")
                        .resizable()
                        .frame(width: 17, height: 17)
                    Text("No payment now")
                        .font(.system(size: 12.fit, weight: .medium))
                        .foregroundColor(Color.hexColor(0x141414).opacity(0.24))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, getBottomSafeAreaHeight() + 8)
    }
}

#Preview {
    SubscribeSwitchPage()
}
