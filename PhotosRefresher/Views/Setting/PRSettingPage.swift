//
//  PRSettingPage.swift

//
//  Created by ty on 2025/11/19.
//

import SwiftUI
import UIKit


struct PRSettingPage: View {
    
    @EnvironmentObject var appRouter: PRAppRouterPath
    
    @State var settings: [PRSettingSection] = [
        
        PRSettingSection(
            id: .slide,
            items: [
                SettingItem(id: .clearSlideHistory, style: .navigation),
            ]
        ),
        PRSettingSection(
            id: .legal,
            items: [
                SettingItem(id: .termsOfUse, style: .navigation),
                SettingItem(id: .privacyPolicy, style: .navigation)
            ]
        )
    ]
    
    var body: some View {
        
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                navBarView
                SettingsView(sections: settings) { action in
                    onTapSettingAction(type: action)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(.white)
        .navigationBarHidden(true)
    }
    
    var navBarView: some View {
        PRCustomNavigationBarView(height: 44) {
            Button {
                appRouter.back()
            } label: {
                Image("icon_nav_return")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        } centerView: {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.mainTextColor)
        } rhsView: {
            EmptyView()
        }
    }
    
    func onTapSettingAction(type: SettingAction) {
        switch type {

        case .navigation(.contactUs):
            PRAppMailHelper.presentSupportEmail()
        case .navigation(.termsOfUse):
            openUrl(WebUrl.terms.fullPath)
        case .navigation(.privacyPolicy):
            openUrl(WebUrl.privatePolicy.fullPath)
        case .navigation(.clearSlideHistory):
            PRSlideCacheManager.shared.cleanAll()
            PRToast.show(message: "succeed")
        default:
            break
        }
    }
    
    func openUrl(_ url: String) {
        if let url = URL(string: url) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }else{
                PRToast.show(message: "Unable to open Email app")
            }
        } else {
            PRToast.show(message: "Failed to open Email app")
        }
    }
    
    /// 更新密码状态
    func updatePwdSetting(enable: Bool) {
        for sectionIndex in settings.indices {
            if settings[sectionIndex].id == .secretSpace {
                if enable {
                    settings[sectionIndex].items = [
                        SettingItem(id: .usePassword, style: .toggle(isOn: enable)),
                        SettingItem(id: .changePassword, style: .navigation)
                    ]
                }else{
                    settings[sectionIndex].items = [
                        SettingItem(id: .usePassword, style: .toggle(isOn: false)),
                    ]
                }
            }
        }
    }
}

struct SettingsView: View {
    let sections: [PRSettingSection]
    let onAction: (SettingAction) -> Void
    var body: some View {
        ScrollView(showsIndicators: false) {
            ForEach(sections, id: \.id) { section in
                Section {
                    ForEach(section.items, id: \.id) { item in
                        SettingItemRow(item: item, onAction: onAction)
                            .frame(height: 60)
                        Rectangle()
                            .fill(Color.black.opacity(0.08))
                            .frame(height: 0.5.fit)
                            .edgesIgnoringSafeArea(.horizontal)
                    }
                } header: {
                    
                    SectionHeaderView(style: section.id.header)
                }
            }
        }
        .background(Color.white)
        .padding(.horizontal, 16)
    }
}



struct SectionHeaderView: View {
    let style: SectionHeaderStyle
    
    var body: some View {
        switch style {
        case .title(let text):
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.hexColor(0x666666))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            
        case .titleWithSubtitle(let title, let subtitle):
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.hexColor(0x666666))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.hexColor(0xA3A3A3))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
    }
}


struct SettingItemRow: View {
    let item: SettingItem
    let onAction: (SettingAction) -> Void
    
    @State private var toggleState: Bool = false
    
    var body: some View {
        switch item.style {
        case .toggle(let isOn):
            Toggle(item.id.title, isOn: Binding(
                get: { toggleState },
                set: { newValue in
                    toggleState = newValue
                    onAction(.toggle(item.id, isOn: newValue))
                }
            ))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.mainTextColor)
            .padding(.trailing, 2)
            .onAppear {
                toggleState = isOn
            }
            
        case .navigation:
            
            Button{
                onAction(.navigation(item.id))
            } label: {
                HStack {
                    Text(item.id.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.mainTextColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle()) // 保证整行可点击
            }
        }
    }
}


#Preview {
    PRSettingPage()
}

