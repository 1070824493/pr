//
//  ThemeButton.swift

//
//  Created by zyb on 2025/8/23.
//

import SwiftUI

enum ThemeButtonType {
    case normal
    case delete
    case guide
    case subscribe
    
    var bgColor: Color {
        switch self {
        case .normal:
            Color.hexColor(0x14A4A4)
        case .delete:
            Color.hexColor(0xFF5329)
        case .guide:
            Color.hexColor(0x141414)
        case .subscribe:
            Color.hexColor(0x186F6F)
        }
    }
}

/// 主题色按钮
struct PRThemeButton: View {
    
    let title: String
    var enable: Bool = true
    var type: ThemeButtonType = .normal
    let action: () -> ()
    
    var body: some View {
        
        Button {
            if enable { action() }
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .frame(height: 48)
                .background(type.bgColor.opacity(enable ? 1 : 0.4))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
