//
//  SubscribeNormalCellView.swift
//  PhotosRefresher
//
//  Created by ty on 2025/11/28.
//

import SwiftUI

struct PRSubscribeNormalCellView: View {
    
    let item: SubscriptionPackageModel
    
    @EnvironmentObject var viewModel: PRSubscribeViewModel
    
    private var isSelected: Bool { viewModel.selectedPackageId == item.skuId }
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color(hex: "186F6F") : Color(hex: "F0F0F0"), lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

            HStack(spacing: 15) {
                Image(isSelected ? "icon_product_selected" : "icon_product_normal")
                    .resizable().frame(width: 24, height: 24)
                    .padding(.leading, 15)
                VStack(alignment: .leading, spacing: 4) {
                    let durationText = viewModel.durationForDisplay(item)
                    Text(viewModel.titleFor(item))
                        .font(.bold16)
                        .foregroundColor(Color(hex: "141414"))
                        .padding(.top, durationText.isEmpty ? 0 : 14)
                    
                    if !durationText.isEmpty {
                        Text(durationText)
                            .font(.regular12)
                            .foregroundColor(isSelected ? Color(hex: "35B923") : Color(hex: "A3A3A3"))
                            .padding(.bottom, 14)
                    }
                }

                Spacer()

                let price = viewModel.priceForDisplay(item)
                if !price.isEmpty {
                    Text(price)
                        .font(.bold16)
                        .foregroundColor(Color(hex: "141414"))
                        .padding(.trailing, 15)
                }
            }
        }
        .frame(height: 64)
        .onTapGesture {
            viewModel.selectedPackageId = item.skuId
            Task {
                await viewModel.purchase()
            }
        }
    }
}

