//
//  LoadingView.swift

//
//

import SwiftUI

enum LoadingViewStyle {
    
    case light
    
    case dark
    
    var image: String {
        switch self {
        case .light:
            return "icon_loading"
        case .dark:
            return "icon_loading_dark"
        }
    }
}

struct PRLoadingView : View {
    
    var showBackground: Bool = false
    
    var style: LoadingViewStyle = .light
    
    @State private var isRotating = false
    
    var body: some View {
        ZStack {
            Image(style.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 24.fit, height: 24.fit)
                .rotationEffect(Angle(degrees: isRotating ? 360 : 0), anchor: .center)
                .background {
                    if showBackground {
                        Rectangle()
                            .fill(.black.opacity(0.56))
                            .frame(width: 70.fit, height: 70.fit)
                            .cornerRadius(16.fit, corners: .allCorners)
                    }
                }
                .onAppear {
                    withAnimation(Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false)
                    ) {
                        self.isRotating = true
                    }
                }
                .onDisappear {
                    self.isRotating = false
                }
        }
    }
    
}
