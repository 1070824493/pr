//
//  SubscribeRandomBubble.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import SwiftUI

struct PRSubscribeRandomBubble: View {
    @State private var joinedDisplay = Int.random(in: 1500...2500)
    @State private var joinedTarget = 0

    private let fiveSecTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let stepTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(joinedDisplay) people have joined this plan today!")
            .font(.regular12)
            .foregroundColor(Color.hexColor(0x141414))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .baselineOffset(3)
            .frame(height: 28, alignment: .center)
            .background(
                Image("subscription_product_bubble")
                    .resizable(
                        capInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
                        resizingMode: .stretch
                    )
            )
            .offset(y: 16)
            .fixedSize(horizontal: true, vertical: true)
            .onAppear { joinedTarget = joinedDisplay }
            .onReceive(fiveSecTimer) { _ in joinedTarget += Int.random(in: 5...20) }
            .onReceive(stepTimer) { _ in if joinedDisplay < joinedTarget { joinedDisplay += 1 } }
    }
}


