//
//  CustomNavigationView.swift

//
//  Created by zyb on 2025/8/21.
//

import SwiftUI

public struct CustomNavigationBarView<LhsView, CenterView, RhsView>: View where LhsView : View, CenterView : View, RhsView : View {
    var lhsView : (() -> LhsView)?
    var centerView : (() -> CenterView)?
    var rhsView : (() -> RhsView)?
    var height: CGFloat = 44
    
    public init(height: CGFloat = 44, @ViewBuilder lhsView: @escaping () -> LhsView,
                @ViewBuilder centerView: @escaping () -> CenterView,
                @ViewBuilder rhsView: @escaping () -> RhsView){
        self.height = height
        self.lhsView = lhsView
        self.centerView = centerView
        self.rhsView = rhsView
    }
    
    public var body: some View {
        
        ZStack(alignment: .center) {
            if let __centerView = centerView {
                HStack(alignment: .center, spacing: 0, content: __centerView)
                    .frame(height: height)
                    .frame(maxWidth: kScreenWidth * 0.6)
            }
            
            HStack(alignment: .center, spacing: 0) {
                //左侧按钮区域
                if let __lhsView = lhsView {
                    HStack(alignment: .center, spacing: 0, content: __lhsView)
                        .frame(height: height)
                }else{
                    Spacer()
                }
                
                //中间使用space撑开
                Spacer()
                
                //右侧按钮区域额
                if let __rhsView = rhsView {
                    HStack(alignment: .center, spacing: 0, content: __rhsView)
                        .frame(height: height)
                }else{
                    Spacer()
                }
            }
        }
        .frame(height: height)
        .padding(EdgeInsets(top: getStatusBarHeight(), leading: 16, bottom: 0, trailing: 16))
        .background(Color.white)
    }
}
