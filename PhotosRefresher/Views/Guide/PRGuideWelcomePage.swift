//
//  GuideWelcomePage.swift

//
//  Created by zyb on 2025/9/6.
//

import SwiftUI
import Lottie

struct PRGuideWelcomePage: View {
    
    let models: [GuideSceneModel] = [
        GuideSceneModel(index: 0, title: "Duplicate Photo Deletion", subTitle: "Next-gen AI chat for real interaction.", imageName: "guide1/data", btnTitle: "Continue", backgroundColor: Color.hexColor(0x39A2A2)),
        GuideSceneModel(index: 1, title: "Clean your gallery Save your time", subTitle: "Save time with smart photo cleanup",imageName: "guide2/data", btnTitle: "Continue", backgroundColor: Color.hexColor(0x5893C8)),
        GuideSceneModel(index: 2, title: "AI detects and deletes duplicate photos", subTitle: "Free up space by removing bad photos", imageName: "guide3/data", btnTitle: "Continue", backgroundColor: Color.hexColor(0x8286D9))
    ]
    
    @EnvironmentObject var viewModel: PRGuideViewModel
    
    @State var hasNext: Bool = false
    
    @State private var progress: Double = 0.0
    @State private var currentPage: Int = 0 {
        didSet{
            progress = Double(currentPage + 1) / Double(models.count)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
//            Image("guide_welcome_header")
//                .resizable()
//                .scaledToFill()
//                .frame(width: kScreenWidth, height: 310)
            VStack {
                ZStack(alignment: .top) {
                    
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 0) {
                                ForEach(models, id: \.index) { model in
                                    VStack(alignment: .center, spacing: 0) {
                                        Spacer().frame(height: getStatusBarHeight() + 56.fit)
                                        Text(model.title)
                                            .font(.system(size: 26.fit, weight: .heavy))
                                            .foregroundColor(Color.white)
                                            .lineLimit(2)
                                            .frame(height: 70)
                                            .padding(.horizontal, 16)
                                            .multilineTextAlignment(.center)
                                        
                                        Text(model.subTitle)
                                            .font(.system(size: 14.fit, weight: .regular))
                                            .foregroundColor(Color.white.opacity(0.65))
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)
                                            .multilineTextAlignment(.center)
                                       
                                        PRLottieView(
                                            animationName: model.imageName,
                                            loopMode: .loop,
                                            speed: 1.0,
                                            bundle: .lottie
                                        )
                                        .frame(width: kScreenWidth, height: kScreenWidth * 410.0 / 360.0)
                                        .padding(.top, 40)

                                        Spacer()
                                    }
                                    .frame(width: kScreenWidth, height: kScreenHeight)
                                    .id(model.index)
                                    .background(model.backgroundColor)
                                }
                            }
                            
                        }
                        .scrollDisabled(true)
                        .onChange(of: currentPage) { page in
                            withAnimation(.easeInOut) {
                                proxy.scrollTo(page, anchor: .leading)
                            }
                        }
                    }
                    
                    VStack {
                        Spacer()
                        PRThemeButton(title: "Continue", type: .guide) {
                            goNextIfNeeded()
                        }
                        .frame(height: 56)
                        .padding(.bottom, 38 + getBottomSafeAreaHeight())
                        .padding(.horizontal, 16)
                    }
                    
                    
                }
                
                
                
            }
            
            
            PRProgressBarView(progress: progress)
                .cornerRadius(4)
                .frame(height: 8)
                .padding(.horizontal, 40)
                .padding(.top, 22.fit + getStatusBarHeight())
                .padding(.bottom, 32.fit)
            
            
        }
        .ignoresSafeArea()
        .frame(maxWidth: kScreenWidth, maxHeight: kScreenHeight)
//        .background(Color.white)
        .onAppear {
            progress = Double(currentPage + 1) / Double(models.count)
        }
    }
    
    
    func goNextIfNeeded() {

        if currentPage >= models.count - 1 {
            if !hasNext {
                viewModel.next()
                hasNext = true
            }
        }else{
            withAnimation {            
                currentPage += 1
            }
        }
    }
}

struct GuideButton: View {
    
    let title: String
    var enable: Bool = true
    let action: () -> ()
    
    
    var body: some View {
        
        Button {
            if enable { action() }
        } label: {
            
            Text(title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.hexColor(0x3867FF).opacity(enable ? 1 : 0.4))
                .cornerRadius(16)
        }
    }
}
