//
//  SubscriptionTopHalfView.swift
//  Dialogo
//
//  
//

import SwiftUI

struct SubscriptionTopHalfView: View {
    

    var body: some View {
        let top = DeviceHelper.safeAreaInsets.top
        let height: CGFloat = 338 + top + 44

        ZStack(alignment: .top) {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "39A2A2"), location: 0.0),
                    .init(color: Color(hex: "39A2A2"), location: 0.5),
                    .init(color: .white, location: 1.0),
                ]),
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 8) {
                
                Image("ic_sub_top_bg")
                    .resizable()
                    .frame(width: 290, height: 305, alignment: .center)
                    .padding(.top, 30 + getStatusBarHeight())
                
                Text("No Limit To Clean your Storage")
                    .font(.bold24)
                    .foregroundColor(Color(hex: "141414"))
                    .minimumScaleFactor(0.9)
                    .padding(.horizontal, 12)

                Text("Get rid of what you don't need")
                    .font(.regular14)
                    .foregroundColor(Color(hex: "141414").opacity(0.48))

                Spacer()
            }
            .padding(.horizontal, 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }



    private func mixColor(from: Color, to: Color, t: CGFloat) -> Color {
        let ui1 = UIColor(from)
        let ui2 = UIColor(to)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let tt = max(0, min(1, t))
        return Color(red: Double(r1 + (r2 - r1) * tt),
                     green: Double(g1 + (g2 - g1) * tt),
                     blue: Double(b1 + (b2 - b1) * tt))
    }
}
