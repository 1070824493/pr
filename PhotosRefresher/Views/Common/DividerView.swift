//
//  DividerView.swift

//
//

import SwiftUI

struct DividerView: View {
    var color: SwiftUI.Color = .black
    var height: CGFloat = fitScale(0.5)
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
            .edgesIgnoringSafeArea(.horizontal)
    }
}


#Preview {
    DividerView()
}
