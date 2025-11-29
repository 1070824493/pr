//
//  PRSlidePage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos

struct PRSlidePage: View {
    
    @EnvironmentObject var uiState: PRUIState
    @EnvironmentObject var appRouter: PRAppRouterPath
    @StateObject private var userManager = PRUserManager.shared
    @StateObject private var vm = PRSlideViewModel()
    
    var body: some View {
        
        ZStack(alignment: .top) {
            bgView
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text(Date().formatted(.dateTime.month(.wide).day()))
                        .font(.bold24)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18 + getStatusBarHeight())
                
                Group {
                    if !vm.hasPermission {
                        PRHomeAuthorizationView {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 77)
                    } else if vm.previewFive.isEmpty {
                        NoPhotosView(current: vm.currentCategory, alternatives: vm.alternativeCategories) { cat in
                            vm.loadCategory(cat)
                        }
                        .frame(height: 434)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 77)
                    } else {
                        FiveCardsPreview(assets: vm.previewFive) {
                            appRouter.navigate(.slideDetail(category: vm.currentCategory))
                        }
                        .padding(.top, 50.fit)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            vm.prepareSet()
        }
    }
    
    var bgView: some View {
        Image("cleaning_home_bg")
            .resizable()
            .scaledToFill()
            .frame(width: kScreenWidth, height: kScreenHeight)
            .clipped()
            .ignoresSafeArea()
    }
}

struct FiveCardsPreview: View {
    let assets: [PHAsset]
    var onTapCenter: () -> Void
    private let provider = PRAssetThumbnailProvider()
    
    var body: some View {
        let w = kScreenWidth
        let h = 450.0
        return ZStack {
            Color.clear.opacity(0.5)
                .frame(width: w, height: h, alignment: .center)
        }
        .overlay(alignment: .topLeading) {
            if assets.indices.contains(1) {
                provider.createThumbnailView(for: assets[1], targetSize: CGSize(width: 194, height: 134))
                    .frame(width: 194, height: 134)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                    )
                    .rotationEffect(.radians(-0.24))
            }
        }
        
        .overlay(alignment: .bottomLeading) {
            if assets.indices.contains(2) {
                provider.createThumbnailView(for: assets[2], targetSize: CGSize(width: 230, height: 141))
                    .frame(width: 230, height: 141)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                    )
                    .rotationEffect(.radians(0.44))
            }
        }
        .overlay(alignment: .topTrailing) {
            if assets.indices.contains(3) {
                provider.createThumbnailView(for: assets[3], targetSize: CGSize(width: 128, height: 181))
                    .frame(width: 128, height: 181)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                    )
                    .rotationEffect(.radians(-0.7))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ZStack {
                if assets.indices.contains(4) {
                    provider.createThumbnailView(for: assets[4], targetSize: CGSize(width: 155, height: 181))
                        .scaledToFill()
                        .frame(width: 155, height: 181)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                        )
                }
            }
        }
        .overlay(alignment: .center) {
            if let a = assets.first {
                provider.createThumbnailView(for: a, targetSize: CGSize(width: 200, height: 269))
                    .frame(width: 200, height: 269)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                    )
                    .rotationEffect(.radians(0.21))
                    .onTapGesture { onTapCenter() }
                    .id(a.localIdentifier)
            }
        }
        
    }
}

private func menuTitle(_ c: PRPhotoCategory) -> String {
    switch c { case .backphoto: return "Photos"; case .screenshot: return "Screenshots"; case .selfiephoto: return "Selfies"; case .livePhoto: return "Live"; default: return c.rawValue }
}

struct NoPhotosView: View {
    let current: PRPhotoCategory
    let alternatives: [PRPhotoCategory]
    var onSelect: (PRPhotoCategory) -> Void
    var body: some View {
        VStack(spacing: 0) {
            Image("cleaning_home_noPermission")
                .resizable()
                .frame(width: 64.fit, height: 64.fit)
                .foregroundColor(.white)
                .padding(.top, 28)
            Text("No photos available")
                .font(.semibold24)
                .foregroundColor(.white)
                .padding(.top, 4)
            Text("Please reselect category or reset viewing history and try again")
                .lineLimit(2)
                .font(.regular16)
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            Text("Try Other Categories")
                .font(.bold18)
                .foregroundColor(.white)
                .padding(.top, 24)
            VStack(spacing: 12) {
                ForEach(alternatives, id: \.rawValue) { c in
                    Button {
                        onSelect(c)
                    } label: {
                        HStack(spacing: 8) {
                            Image(c.slideImageName)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(c.slideTitle)
                                .font(.regular14)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.hexColor(0x141414, alpha: 0.9))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 16)
        }
    }

}

struct ReviewCompleteView: View {
    let hasTrash: Bool
    var onMore: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Review Complete").font(.bold24).foregroundColor(.white)
            PRThemeButton(title: "One More Set", action: onMore)
                .frame(width: 220)
            Spacer()
        }
        .padding()
    }
}

