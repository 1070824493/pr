//
//  PRSlideDetailPage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos
import UIKit
import CollectionViewPagingLayout

extension PHAsset: @retroactive Identifiable {
    public var id: String {
        self.localIdentifier
    }
}

struct PRSlideDetailPage: View {
    @State var category: PRAssetType {
        didSet{
            PRAppUserPreferences.shared.currentSlideCategory = category
        }
    }
    @EnvironmentObject var uiState: PRUIState
    @EnvironmentObject var appRouter: PRAppRouterPath
    
    @Environment(\.dismiss) var dismiss
    @State private var assets: [PHAsset] = []
    @State private var index: Int = 0
    @State private var sessionTrash: [PHAsset] = []
    @State private var showCategoryMenu: Bool = false
    @State private var dragActive: Bool = false
    @State private var dragProgress: Double = 0
    @State private var overlayOpacity: Double = 0
    @State private var deletedIndexStack: [Int] = []
    
    @State private var currentAxisLock: ZoomInteractiveCard.AxisLock = .none
    
    var body: some View {
        ZStack(alignment: .top) {
            Image("cleaning_home_bg").resizable().scaledToFill().ignoresSafeArea()
            VStack(spacing: 0) {
                if !dragActive && overlayOpacity < 0.1 {
                    navBarView
                }
                
                CustomPageView(
                    index: $index,
                    assets: assets,
                    pushToTrash: { asset in
                        // 实现删除逻辑
                        pushToTrash(asset)
                    },
                    openTrashReview: {
                        // 打开垃圾箱
                        openTrashReview()
                    },
                    onDragUpdate: { active, progress in
                        dragActive = active
                        dragProgress = progress
                        if active {
                            overlayOpacity = progress
                        } else {
                            withAnimation(.easeOut(duration: 0.6)) {
                                overlayOpacity = 0
                            }
                        }
                    }
                )
                .id(assets.map { $0.localIdentifier }.joined(separator: ","))
                
                
                
                HStack(spacing: 16) {
                    Text(timeText(for: assets.indices.contains(index) ? assets[index] : nil))
                        .font(.system(size: 14.fit, weight: .regular, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                    
                    
                    Button(action: { undoLastDelete() }) {
                        Image(systemName: "arrow.uturn.left").foregroundColor(.white)
                    }
                    .opacity(sessionTrash.isEmpty ? 0.4 : 1)
                    .frame(width: 48, height: 48)
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24 + getBottomSafeAreaHeight())
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea()
        .onAppear { loadAssets(for: category) }
        .onDisappear(perform: {
            PRAppUserPreferences.shared.hasShowSwipeUpDelete = true
        })
        .overlay(alignment: .top) {
            if showCategoryMenu {
                CategoryAnchoredMenu(current: category) { c in
                    switchCategory(c)
                    showCategoryMenu = false
                } onDismiss: { showCategoryMenu = false }
            }
            LinearGradient(colors: [Color.red.opacity(overlayOpacity), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .top)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .opacity(overlayOpacity > 0 ? 1 : 0)
                .animation(.easeOut(duration: 0.6), value: overlayOpacity)
                .overlay(alignment: .top, content: {
                    ZStack {
                        HStack(spacing: 8) {
                            Image(systemName: "trash").foregroundColor(.white)
                            Text("Delete").font(.system(size: 18.fit, weight: .bold, design: .default)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .opacity(overlayOpacity > 0 ? 1 : 0)
                    .padding(.top, 30 + getStatusBarHeight())
                })
        }
    }
    
    var navBarView: some View {
        ZStack {
            HStack(spacing: 12) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    if assets.isEmpty {
                        Text("0/0")
                            .font(.system(size: 14.fit, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }else{
                        Text("\(min(index+1, max(assets.count, 1)))/\(max(assets.count, 1))")
                            .font(.system(size: 14.fit, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }
                }
                
                
                Spacer()
                
                
                Button(action: { openTrashReview() }) {
                    Image("ic_slide_delete")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Button(action: { showCategoryMenu = true }) {
                    HStack(spacing: 8) {
                        Text(menuTitle(category))
                            .font(.system(size: 18.fit, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down").foregroundColor(.white)
                    }
                    .frame(height: 32)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
            
            if !PRAppUserPreferences.shared.hasShowSwipeUpDelete {
                Text("Swipe up to delete")
                    .font(.system(size: 24.fit, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .padding(.top, 48 + getStatusBarHeight())
                    .breathing()
            }
        }
        .frame(height: 48)
        .padding(.top, getStatusBarHeight())
    }
    
    private func loadAssets(for cat: PRAssetType) {
        let ids = mapFor(cat).localIdentifiers
        let unviewed = PRSlideCacheManager.shared.unviewedFirst(limit: 15, category: cat, sourceIDs: ids)
        assets = fetchAssetEntities(by: unviewed)
        index = 0
    }
    
    private func switchCategory(_ cat: PRAssetType) {
        loadAssets(for: cat)
        category = cat
        if assets.isEmpty {
            appRouter.backToRoot()
        }
    }
    
    private func mapFor(_ cat: PRAssetType) -> PRAssetsInfo {
        let m = PRAssetsCleanManager.shared
        switch cat {
        case .PhotosScreenshot: return m.assetsInfoForScreenShot
        case .PhotosLive: return m.assetsInfoForLivePhoto
        case .selfiephoto: return m.assetsInfoForSelfiePhotos
        case .backphoto: return m.assetsInfoForBackPhotos
        default: return m.assetsInfoForBackPhotos
        }
    }
    
    private func pushToTrash(_ asset: PHAsset) {
        deletedIndexStack.append(index)
        sessionTrash.append(asset)
        assets.removeAll { $0.localIdentifier == asset.localIdentifier }
        index = min(index, max(assets.count - 1, 0))
        if assets.isEmpty {
            openTrashReview()
        }
        PRAppUserPreferences.shared.hasShowSwipeUpDelete = true
    }
    private func undoLastDelete() {
        guard let last = sessionTrash.popLast() else { return }
        if let targetIndex = deletedIndexStack.popLast() {
            let insertAt = min(max(0, targetIndex), max(0, assets.count))
            assets.insert(last, at: insertAt)
            index = insertAt
        }
    }
    private func timeText(for asset: PHAsset?) -> String {
        guard let d = asset?.creationDate else { return "" }
        let now = Date()
        let interval = now.timeIntervalSince(d)
        let hourSec: Double = 3600
        let daySec: Double = 86400
        if interval < daySec {
            var hours = Int(interval / hourSec)
            if hours < 1 { hours = 1 }
            return "\(hours) " + (hours == 1 ? "hour ago" : "hours ago")
        } else {
            let days = Int(interval / daySec)
            if days > 365 {
                let years = Int(days / 365)
                return "\(years) " + (years == 1 ? "year ago" : "years ago")
            } else {
                return "\(days) " + (days == 1 ? "day ago" : "days ago")
            }
        }
    }
    private func menuTitle(_ c: PRAssetType) -> String {
        switch c {
        case .backphoto: return "Photos"
        case .PhotosScreenshot: return "Screenshots"
        case .selfiephoto: return "Selfies"
        case .PhotosLive: return "Live"
        default: return c.rawValue
        }
    }
    
    
    private func openTrashReview() {
        let m = TrashReviewViewModel(assets: sessionTrash, onConfirm: { selected in
            PRAssetsHelper.shared.purgeResourcesWithPrivilegeVerification(
                selected,
                assetIDs: selected.map { $0.localIdentifier },
                uiState: uiState,
                from: "slide-modal-\(category.rawValue)"
            ) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        sessionTrash.removeAll()
                        uiState.modalDestination = nil
                        PRToast.show(message: "删除成功")
                    }
                case .failure:
                    DispatchQueue.main.async { }
                }
            }
        }, onSkip: {
            
            getNextUnviewedSource(limit: 15, category: category)
            
        }, onDismiss: {
            uiState.modalDestination = nil
        })
        uiState.modalDestination = .trashReview(model: m)
    }
    
    /// 获取下一轮图片
    func getNextUnviewedSource(limit: Int, category: PRAssetType) {
        let sourceIDs = mapFor(category).localIdentifiers
        //先标记已读,
        PRSlideCacheManager.shared.markViewed(category: category, ids: assets.map({$0.localIdentifier}))
        //再重新获取
        let nextIDs = PRSlideCacheManager.shared.unviewedFirst(limit: limit, category: category, sourceIDs: sourceIDs)
        self.assets = fetchAssetEntities(by: nextIDs)
        NotificationCenter.default.post(name: .slideSessionDidAdvance, object: nil, userInfo: ["category": category.rawValue, "nextIDs": nextIDs])
        index = 0
        uiState.modalDestination = nil
        if assets.isEmpty {
            appRouter.back()
        }
    }
}

extension PRAssetType {
    var slideImageName: String {
        switch self {
        case .PhotosScreenshot:
            return "ic_screenshot"
        case .PhotosLive:
            return "ic_livephoto"
        case .selfiephoto:
            return "icon_self"
        case .backphoto:
            return "ic_photo"
        default:
            return ""
        }
    }
    
    var slideTitle: String {
        switch self {
        case .PhotosScreenshot:
            return "Screenshots"
        case .PhotosLive:
            return "Live"
        case .selfiephoto:
            return "Selfies"
        case .backphoto:
            return "Photos"
        default:
            return ""
        }
    }
}

private struct CategoryAnchoredMenu: View {
    let current: PRAssetType
    var onSelect: (PRAssetType) -> Void
    var onDismiss: () -> Void
    private let width: CGFloat = 240
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { onDismiss() }
            VStack(spacing: 0) {
                Button(action: { onSelect(.backphoto) }) { MenuRow(title: PRAssetType.backphoto.slideTitle, iconName: PRAssetType.backphoto.slideImageName, selected: current == .backphoto) }
                Divider().overlay(Color.white.opacity(0.15))
                Button(action: { onSelect(.PhotosScreenshot) }) { MenuRow(title: PRAssetType.PhotosScreenshot.slideTitle, iconName: PRAssetType.PhotosScreenshot.slideImageName, selected: current == .PhotosScreenshot) }
                Divider().overlay(Color.white.opacity(0.15))
                Button(action: { onSelect(.selfiephoto) }) { MenuRow(title: PRAssetType.selfiephoto.slideTitle, iconName: PRAssetType.selfiephoto.slideImageName, selected: current == .selfiephoto) }
                Divider().overlay(Color.white.opacity(0.15))
                Button(action: { onSelect(.PhotosLive) }) { MenuRow(title: PRAssetType.PhotosLive.slideTitle, iconName: PRAssetType.PhotosLive.slideImageName, selected: current == .PhotosLive) }
            }
            .frame(width: width)
            .background(Color.black.opacity(0.65))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
            .offset(x: (kScreenWidth - width) / 2.0, y: 48 + getStatusBarHeight())
        }
    }
}

private struct MenuRow: View {
    let title: String
    let iconName: String
    let selected: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(iconName)
                .resizable()
                .frame(width: 16, height: 16)
            Text(title).font(.system(size: 14.fit, weight: .regular, design: .default)).foregroundColor(.white)
            Spacer()
            if selected {
                
                Image("ic_slide_select")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

#Preview {
    PRSlideDetailPage(category: .backphoto)
}

struct ZoomInteractiveCard: View {
    let asset: PHAsset
    var onDelete: () -> Void
    var onDragUpdate: ((Bool, Double) -> Void)? = nil
    var onAxisLockChange: ((AxisLock) -> Void)? = nil
    var isPageDragging: Bool = false  // 新增：页面是否在拖动
    
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var isDragging: Bool = false
    @State private var axisLock: AxisLock = .none
    @State private var settledOffset: CGSize = .zero
    @State private var isDeleting: Bool = false
    private let provider = PRAssetThumbnailProvider()
    
    enum AxisLock { case none, horizontal, vertical }
    
    var body: some View {
        GeometryReader { geo in
            let width = kScreenWidth - 30
            let size = CGSize(width: width, height: geo.size.height * 0.82)
            let threshold: CGFloat = 110
            let gesture = DragGesture(minimumDistance: 0)
                .onChanged { g in
                    // 如果页面正在水平拖动，不处理卡片手势
                    if isPageDragging { return }
                    
                    if axisLock == .none {
                        let dx = abs(g.translation.width)
                        let dy = abs(g.translation.height)
                        if dx > dy + 8 {
                            axisLock = .horizontal
                            onAxisLockChange?(.horizontal)
                        }
                        else if dy > dx + 8 && g.translation.height < 0 {
                            axisLock = .vertical
                            onAxisLockChange?(.vertical)
                        }
                    }
                    if axisLock == .vertical {
                        let progress = max(0, min(1, (-g.translation.height) / 160))
                        onDragUpdate?(true, progress)
                    } else {
                        onDragUpdate?(false, 0)
                    }
                }
                .updating($dragOffset) { v, s, _ in
                    if !isPageDragging {
                        s = v.translation
                    }
                }
                .updating($isDragging) { _, s, _ in
                    if !isPageDragging {
                        s = true
                    }
                }
                .onEnded { g in
                    if isPageDragging { return }
                    
                    let predictedY = g.predictedEndTranslation.height
                    let shouldDelete = (g.translation.height < -threshold) || (predictedY < -(threshold*0.8))
                    if shouldDelete && axisLock == .vertical {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            settledOffset = CGSize(width: 0, height: -geo.size.height)
                            isDeleting = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { onDelete() }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { settledOffset = .zero }
                    }
                    onDragUpdate?(false, 0)
                    axisLock = .none
                    onAxisLockChange?(.none)
                }
            
            ZStack(alignment: .top) {
                provider.constructVisualElement(for: asset, targetSize: size)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(24)
                    .offset(x: 0,
                            y: (isDeleting || axisLock == .vertical || settledOffset.height < 0) ? (settledOffset.height + (axisLock == .vertical ? dragOffset.height : 0)) : 0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.9), value: dragOffset)
                    .simultaneousGesture(gesture)  // 改为 simultaneousGesture
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

