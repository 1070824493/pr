//
//  LLAlertView.swift

//
//  Created by R on 2025/4/8.
//

import SwiftUI

struct PRAlertView: View {

    var model: PRAlertModalModel
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20).padding(0)
            if !model.imgName.isEmpty {
                Image(model.imgName)
                    .resizable()
                    .frame(width: fitScale(98), height: fitScale(98))
            }
            
            if !model.title.isEmpty {
                Text(model.title)
                    .font(.system(size: fitScale(18), weight: .semibold))
                    .foregroundColor(Color.hexColor(0x131414))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, fitScale(11.5))
            }
            
            if !model.desc.isEmpty {
                Text(model.desc)
                    .font(.system(size: fitScale(14)))
                    .foregroundColor(Color.hexColor(0x131414))
                    .padding(.bottom, fitScale(20))
                    .lineSpacing(fitScale(2.5))
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 10) {
                Button {
                    // go to next session
                    model.actionHandler?(.first)
                } label: {
                    Text(model.firstBtnTitle)
                        .font(.system(size: fitScale(16), weight: .semibold))
                        .foregroundColor(Color.hexColor(0x626466))
                        .frame(height: fitScale(44))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .background(Color.hexColor(0xF5F5F5))
                        .cornerRadius(fitScale(12))
                }
                .padding(.bottom, fitScale(24))
                
                
                Button {
                    // go to next session
                    model.actionHandler?(.second)
                } label: {
                    Text(model.secondBtnTitle)
                        .font(.system(size: fitScale(16), weight: .semibold))
                        .foregroundColor(Color.white)
                        .frame(height: fitScale(44))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        
                }
                .background(
                    Color.hexColor(0x3867FF)
                )
                .cornerRadius(fitScale(12))
                .padding(.bottom, fitScale(24))
                
            }
            
            
        }
        .padding(.horizontal, fitScale(20))
    }
}

#Preview {
//    LLAlertView(imgName: "icon_emoji_cry", title: "Are you sure?", desc: "You won't receive a feedback report unless you complete the session.", firstBtnTitle: "Continue Call", secondBtnTitle: "Leave Call") { action in
//    }
    
    PRAlertView(model: PRAlertModalModel(
        imgName: "icon_emoji_cry", title: "Are you sure to jump to this exercise?", desc: "Following your personalized path will boost your English, but you can still jump to this exercise if you prefer.", firstBtnTitle: "Continue Call", secondBtnTitle: "Leave Call") { action in
       }
    )
}
