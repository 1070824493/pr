//
//  CommonLoadingModify.swift

//
//  Created by zyb on 2025/8/28.
//

import SwiftUI

public struct PRCommonLoadingModifier: ViewModifier {
    let show: Bool
    @ViewBuilder @MainActor public func body(content: Self.Content) -> some View {
        ZStack {
            content
            if show {
                PRLoadingView(showBackground: true)
            }
        }
        .animation(.easeInOut, value: show)
    }
}

extension View {
    public func showCommonLoading(_ show: Bool) -> some View {
        self.modifier(PRCommonLoadingModifier(show: show))
    }
}
