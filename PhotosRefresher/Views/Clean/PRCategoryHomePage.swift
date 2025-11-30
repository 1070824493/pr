//
//  PRCategoryHomePage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos
import Combine
import CollectionViewPagingLayout

struct PRCategoryHomePage: View {
    
    @StateObject private var vm: PRCategoryHomeViewModel
    
    @EnvironmentObject var appRouterPath: PRAppRouterPath
    @EnvironmentObject private var uiState: PRUIState
    
    @State private var topInset: CGFloat = 0
    private var barHeight: CGFloat { topInset + 44 }
    
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var didBindOverlaySubscriber = false
    @State private var didStartPipeline = false
    
    private let thumbProvider = PRAssetThumbnailProvider()
    
    init() {
        _vm = StateObject(wrappedValue: .init(manager: .shared))
    }
    
    let allCategory: [PRAssetType] = [
        .PhotosBlurry,
        .PhotosDuplicate,
        .PhotosSimilar,
        .PhotosScreenshot,
        .VideoLarge,
        .VideoAll,
        .PhotosLive,
        .PhotosText,
//        .selfiephoto,
//        .backphoto
    ]
    
    private var hasPermission: Bool {
        if PRAppUserPreferences.shared.accessGalleryPermission {
            if PRAppUserPreferences.shared.galleryPermissionState != .authorized {
                DispatchQueue.main.async {
                    PRAppUserPreferences.shared.galleryPermissionState = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                }
            }
        }
        
        switch PRAppUserPreferences.shared.galleryPermissionState {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }
    
    let scaleOptions = ScaleTransformViewOptions(
        minScale: 0.9,
        scaleRatio: 0.2,
        translationRatio: CGPoint(x: 0.66, y: 0.2),
        maxTranslationRatio: CGPoint(x: 2, y: 0),
        keepVerticalSpacingEqual: true,
        keepHorizontalSpacingEqual: true,
        scaleCurve: .linear,
        translationCurve: .linear
    )
    
    public var body: some View {
        ZStack(alignment: .top) {
            bgView
            .frame(width: kScreenWidth,
                       height: kScreenHeight)
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                PRHomeHeaderView(
                    totalCleanable: vm.totalCleanable,
                    disk: vm.disk) {
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Group {
                    if hasPermission {

                        ScalePageView(allCategory) { category in
                            
                            let snap = vm.snapshots[category] ?? CategoryItemVM(category: category, bytes: 0, repID: nil, repAsset: nil, totalCount: 0)
                            PRCategoryPageCard(snapshot: snap, thumbProvider: thumbProvider) {
                                
                                clickCellAction(category: category)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .options(scaleOptions)
                        .pagePadding(horizontal: .fractionalWidth(16.0 / kScreenWidth))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .frame(width: kScreenWidth - 32)
                        
                        
                        
                    } else {
                        PRHomeAuthorizationView(
                            onTapAllow: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(24)
                .clipped()
                .padding(.bottom, uiState.homefooterHeight + getBottomSafeAreaHeight() + 30)
                
                
            }
            .padding(.top, 18 + getStatusBarHeight())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            PRHomeTopBar(
                navBarHeight: barHeight,
                isVip: (PRUserManager.shared.checkVipEligibility()),
                onTap: {
                    appRouterPath.navigate(.settingPage)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .ignoresSafeArea(edges: .top)

        }
        .environmentObject(vm)
        .preferredColorScheme(.light)
        .onAppear {
            if topInset == 0 {
                topInset = DeviceHelper.safeAreaInsets.top // 只取一次
            }
            bindAndMaybeStart()
            delay(0.5) {
                checkPermissionAlert()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prStartPipeline)) { _ in
            bindAndMaybeStart()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                PRAppReviewManager.shared.reviewIfNeeded()
            }
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
    
    private func clickCellAction(category: PRAssetType) {
        switch category {
        
        case .PhotosSimilar, .PhotosDuplicate:
            appRouterPath.navigate(.exploreSecondRepeat(cardID: category.rawValue))
        
        case .VideoAll, .VideoLarge:
            appRouterPath.navigate(.exploreDoubleFeed(cardID: category, isVideo: true))
        default:
            appRouterPath.navigate(.exploreDoubleFeed(cardID: category, isVideo: false))
        }
    }
    
    func checkPermissionAlert() {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else {
            return
        }
        if !PRAppUserPreferences.shared.accessGalleryPermission, !PRGlobalOverlay.shared.isDisplaying {
            PRGlobalOverlay.shared.displayHUDOverlay = true
            PRGlobalOverlay.shared.show(body: {
                PRAlbumPermissionView { ok in
                    PRAppUserPreferences.shared.accessGalleryPermission = true
                    if ok {
                        PRAppUserPreferences.shared.galleryPermissionState = .authorized
                        NotificationCenter.default.post(name: .prStartPipeline, object: nil)
                    } else {
                        PRAppUserPreferences.shared.galleryPermissionState = .denied
                        PRGlobalOverlay.shared.hide()
                    }
                }
            }, showAnimation: .slideFromRight)
        }
        else if PRAppUserPreferences.shared.accessGalleryPermission,
                PRAppUserPreferences.shared.galleryPermissionState == .authorized,
                !PRGlobalOverlay.shared.isDisplaying {
            if !PRGlobalOverlay.shared.displayHUDOverlay {
                PRGlobalOverlay.shared.displayHUDOverlay = true
                PRGlobalOverlay.shared.show {
                    PRHomeHUDView(type: .notText) {
                        PRGlobalOverlay.shared.hide()
                    }
                }
            }
        }
    }
    
    private func bindAndMaybeStart() {

        guard PRAppUserPreferences.shared.galleryPermissionState == .authorized else { return }

        if !didBindOverlaySubscriber {
            didBindOverlaySubscriber = true

            Publishers.Merge(
                Just(PRAssetsCleanManager.shared.assetsInfoForSimilar),
                PRAssetsCleanManager.shared.$assetsInfoForSimilar.dropFirst()
            )
            .receive(on: DispatchQueue.main)
            .first { !$0.assets.isEmpty || !$0.groupAssets.isEmpty }
            .delay(for: 0.8, scheduler: DispatchQueue.main)
            .sink { _ in
                PRGlobalOverlay.shared.hide()
            }
            .store(in: &cancellables)
        }

        if !didStartPipeline {
            didStartPipeline = true
            vm.ensureStartedIfAllowed()
        }
    }
}

struct PRCategoryPageCard: View {
    let snapshot: CategoryItemVM
    let thumbProvider: PRAssetThumbnailProvider
    var onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width
            let cardH = geo.size.height
            let asset = snapshot.repAsset?.first

            ZStack(alignment: .bottomLeading) {
                Group {
                    if let a = asset {
                        thumbProvider.constructVisualElement(for: a, targetSize: CGSize(width: cardW, height: cardH), preferFastFirst: true)
                            .frame(width: cardW, height: cardH)
                            .clipped()
                    } else {
                        VStack {
                            Spacer().frame(height: 120)
                            Image(snapshot.category.emptyIconName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            PRBlurView(style: .systemMaterialDark)
                        }
                        .frame(alignment: .top)
                    }
                }

                
                Image("bottom_shadow")
                    .resizable()
                    .frame(height: 138)
                
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.bytes.prettyBytes)
                            .font(.system(size: 32.fit, weight: .heavy, design: .default))
                            .foregroundColor(.white)
                        Text(snapshot.category.title)
                            .font(.system(size: 20.fit, weight: .bold, design: .default))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    
                    Spacer()

                    Button(action: onTap) {
                        HStack(spacing: 8) {
                            Image("home_clean_icon")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text("Clean")
                                .font(.system(size: 18.fit, weight: .bold, design: .default))
                                .foregroundColor(.white)
                        }
                        .frame(width: 107.fit, height: 56.fit)
                        .background(Color.hexColor(0x14A4A4))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 56)
                .padding(28)
                
                
            }
            .frame(width: cardW, height: cardH)
            .background(Color.white.opacity(0.1))
            .cornerRadius(24)
            .onTapGesture { onTap() }
        }
    }
}


extension Int64 {
    var prettyBytes: String {
        let KB: Double = 1024
        let MB = KB * 1024
        let GB = MB * 1024
        let v = Double(self)
        if v >= GB { return String(format: "%.1f GB", v/GB) }
        else if v >= MB { return String(format: "%.1f MB", v/MB) }
        else if v >= KB { return String(format: "%.0f KB", v/KB) }
        else { return "\(self) B" }
    }
    
    var prettyBytesTuple: (String, String) {
        let KB: Double = 1024
        let MB = KB * 1024
        let GB = MB * 1024
        let v = Double(self)
        if v >= GB { return (String(format: "%.1f ", v/GB), "GB") }
        else if v >= MB { return (String(format: "%.1f ", v/MB), "MB") }
        else if v >= KB { return (String(format: "%.0f ", v/KB), "KB") }
        else { return ("\(self) ", "B") }
    }
}

extension PRAssetType {
    var title: String {
        switch self {
        case .VideoAll:      return "All Videos"
        case .VideoLarge:    return "Large Videos"
        case .PhotosBlurry:   return "Blurry Photos"
        case .PhotosDuplicate:return "Duplicate Photos"
        case .PhotosScreenshot:    return "Screenshots"
        case .PhotosSimilar:  return "Similar Photos"
        case .PhotosText:     return "Text Photos"
        case .PhotosLive:     return "Live Photos"
        default:             return self.rawValue
        }
    }
    var emptyIconName: String { "clean_empty_\(self.rawValue)" }
}

extension Notification.Name {
    static let prStartPipeline = Notification.Name("PRstartPipeline")
}

struct CategoryItemVM: Equatable, Hashable {
    let category: PRAssetType
    let bytes: Int64
    let repID: [String]?
    let repAsset: [PHAsset]?
    let totalCount: Int

    static func == (lhs: CategoryItemVM, rhs: CategoryItemVM) -> Bool {
        lhs.category == rhs.category &&
        lhs.bytes == rhs.bytes &&
        lhs.repID == rhs.repID &&
        lhs.hasAsset == rhs.hasAsset &&
        lhs.totalCount == rhs.totalCount
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(category)
        hasher.combine(bytes)
        hasher.combine(repID)
        hasher.combine(hasAsset)
        hasher.combine(totalCount)
    }

    var hasAsset: Bool { repAsset != nil }
}





