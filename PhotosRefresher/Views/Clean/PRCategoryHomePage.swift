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
    
    @EnvironmentObject var appRouterPath: AppRouterPath
    @EnvironmentObject private var uiState: UIState
    
    @State private var topInset: CGFloat = 0
    private var barHeight: CGFloat { topInset + 44 }
    
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var didBindOverlaySubscriber = false
    @State private var didStartPipeline = false
    
    private let thumbProvider = PRAssetThumbnailProvider()
    
    init() {
        _vm = StateObject(wrappedValue: .init(manager: .shared))
    }
    
    let allCategory: [PhotoCategory] = [
        .blurryphoto,
        .duplicatephoto,
        .similarphoto,
        .screenshot,
        .largevideo,
        .allvideo,
        .livePhoto,
        .textphoto,
//        .selfiephoto,
//        .backphoto
    ]
    
    private var hasPermission: Bool {
        if AppUserPreferences.shared.hasFinishAlbumPermission {
            if AppUserPreferences.shared.albumPermissionStatus != .authorized {
                DispatchQueue.main.async {
                    AppUserPreferences.shared.albumPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                }
            }
        }
        
        switch AppUserPreferences.shared.albumPermissionStatus {
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
                isVip: (UserManager.shared.userInfo?.vipStatus == 1),
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
        .onReceive(NotificationCenter.default.publisher(for: .ckStartPipeline)) { _ in
            bindAndMaybeStart()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                AppReviewManager.shared.reviewIfNeeded()
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
    
    private func clickCellAction(category: PhotoCategory) {
        switch category {
        
        case .similarphoto, .similarvideo, .duplicatephoto:
            appRouterPath.navigate(.exploreSecondRepeat(cardID: category.rawValue))
        
        case .allvideo, .largevideo:
            appRouterPath.navigate(.exploreDoubleFeed(cardID: category, isVideo: true))
        default:
            appRouterPath.navigate(.exploreDoubleFeed(cardID: category, isVideo: false))
        }
    }
    
    func checkPermissionAlert() {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else {
            return
        }
        if !AppUserPreferences.shared.hasFinishAlbumPermission, !GlobalOverlay.shared.isPresenting {
            GlobalOverlay.shared.showOverlayHUDView = true
            GlobalOverlay.shared.present(content: {
                PRAlbumPermissionView { ok in
                    AppUserPreferences.shared.hasFinishAlbumPermission = true
                    if ok {
                        AppUserPreferences.shared.albumPermissionStatus = .authorized
                        NotificationCenter.default.post(name: .ckStartPipeline, object: nil)
                    } else {
                        AppUserPreferences.shared.albumPermissionStatus = .denied
                        GlobalOverlay.shared.dismiss()
                    }
                }
            },animation: .rightToLeft)
        }
        else if AppUserPreferences.shared.hasFinishAlbumPermission,
                AppUserPreferences.shared.albumPermissionStatus == .authorized,
                !GlobalOverlay.shared.isPresenting {
            if !GlobalOverlay.shared.showOverlayHUDView {
                GlobalOverlay.shared.showOverlayHUDView = true
                GlobalOverlay.shared.present {
                    PRHomeHUDView(type: .notText) {
                        GlobalOverlay.shared.dismiss()
                    }
                }
            }
        }
    }
    
    private func bindAndMaybeStart() {

        guard AppUserPreferences.shared.albumPermissionStatus == .authorized else { return }

        if !didBindOverlaySubscriber {
            didBindOverlaySubscriber = true

            Publishers.Merge(
                Just(PRPhotoMapManager.shared.similarPhotosMap),
                PRPhotoMapManager.shared.$similarPhotosMap.dropFirst()
            )
            .receive(on: DispatchQueue.main)
            .first { !$0.assets.isEmpty || !$0.doubleAssets.isEmpty }
            .delay(for: 0.8, scheduler: DispatchQueue.main)
            .sink { _ in
                GlobalOverlay.shared.dismiss()
            }
            .store(in: &cancellables)
        }

        if !didStartPipeline {
            didStartPipeline = true
            vm.ensureStartedIfAllowed()
        }
    }
}

struct PRHomePagingView: View {
    let items: [PhotoCategory]
    var onTapClean: (_ tappedCategory: PhotoCategory) -> Void
    @EnvironmentObject var vm: PRCategoryHomeViewModel
    @State private var selection: Int = 0
    private let thumbProvider = PRAssetThumbnailProvider()

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                let snap = vm.snapshots[item] ?? CategoryItemVM(category: item, bytes: 0, repID: nil, repAsset: nil, totalCount: 0)
                PRCategoryPageCard(snapshot: snap, thumbProvider: thumbProvider) {
                    onTapClean(item)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        thumbProvider.thumbnailView(for: a, targetSize: CGSize(width: cardW, height: cardH), preferFastFirst: true)
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
                            BlurView(style: .systemMaterialDark)
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
                            .font(.heavy32)
                            .foregroundColor(.white)
                        Text(snapshot.category.title)
                            .font(.bold20)
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    
                    Spacer()

                    Button(action: onTap) {
                        HStack(spacing: 8) {
                            Image("home_clean_icon")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text("Clean")
                                .font(.bold18)
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

extension PhotoCategory {
    var title: String {
        switch self {
        case .blurryphoto:   return "Blurry Photos"
        case .duplicatephoto:return "Duplicate Photos"
        case .screenshot:    return "Screenshots"
        case .similarphoto:  return "Similar Photos"
        case .textphoto:     return "Text Photos"
        case .livePhoto:     return "Live Photos"
        case .allvideo:      return "All Videos"
        case .largevideo:    return "Large Videos"
        default:             return self.rawValue
        }
    }
    var emptyIconName: String { "clean_empty_\(self.rawValue)" }
}

extension Notification.Name {
    static let ckStartPipeline = Notification.Name("CKCleaningHomeView.startPipeline")
}

struct CategoryItemVM: Equatable, Hashable {
    let category: PhotoCategory
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





