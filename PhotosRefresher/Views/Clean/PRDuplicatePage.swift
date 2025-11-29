//
//  PRDuplicatePage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos
import Combine

// MARK: - Bytes 格式化

private func checkFormatBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 KB" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    var v = Double(bytes)
    var i = 0
    while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
    return (v >= 10 || i == 0) ? String(format: "%.0f %@", v, units[i])
                                : String(format: "%.1f %@", v, units[i])
}

// MARK: - Scroll offset key（自定义导航显隐）

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - 主视图：相似/重复 列表页（双排组）

struct PRDuplicatePage: View {
    // 卡片 ID：similarphoto / duplicatephoto / （预留 similarvideo）
    let cardID: String
    init(_ cardID: String, thumbProvider: PRAssetThumbnailProvider? = nil) {
        self.cardID = cardID
        // 也可外部注入 provider，便于全局复用/测试
        self._thumbProvider = State(initialValue: thumbProvider ?? PRAssetThumbnailProvider())
    }

    // 依赖
    @ObservedObject private var manager = PRPhotoMapManager.shared
    @State private var thumbProvider: PRAssetThumbnailProvider

    // 数据源：[[PRPhotoAssetModel]]（从 Map 读取）
    @State private var doubleModels: [[PRPhotoAssetModel]] = []

    // 选择集：使用 ID（localIdentifier）
    @State private var selectedIDs: Set<String> = []
    @State private var selectedBytes: Int64 = 0

    // UI 状态
    @State private var scrollOffsetY: CGFloat = 0
    private let navTitleRevealHeight: CGFloat = 64

    // 订阅/删除
    @State private var cancellable: AnyCancellable?
    @EnvironmentObject var appRouterPath: PRAppRouterPath
    @EnvironmentObject private var uiState: PRUIState

    // MARK: 标题/副标题
    private var headerTitle: String {
        switch cardID {
        case "similarphoto":   return "Similar Photos"
        case "duplicatephoto": return "Duplicate Photos"
        case "similarvideo":   return "Similar Videos"
        default:               return "Library"
        }
    }
    private var vcellSuffix: String {
        switch cardID {
        case "duplicatephoto": return "Duplicate"
        default:               return "Similar"
        }
    }

    // 扁平化（懒用）
    private var flatModels: [PRPhotoAssetModel] { doubleModels.flatMap { $0 } }
    private var totalDisorderCount: Int { flatModels.count }
    private var allSelected: Bool { !flatModels.isEmpty && selectedIDs.count == flatModels.count }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geo.frame(in: .named("ExploreDuplicateView.scroll")).origin.y
                    )
                }.frame(height: 0)

                headerView

                LazyVStack(spacing: 0) {
                    ForEach(doubleModels.indices, id: \.self) { section in
                        groupSection(section: section).background(.white)
                    }
                }
                .background(Color.white)

                Spacer(minLength: 120)
            }
            .coordinateSpace(name: "ExploreDuplicateView.scroll")
            .background(Color.white)
            .onPreferenceChange(ScrollOffsetKey.self) { self.scrollOffsetY = $0 }

            if doubleModels.isEmpty {
                VStack(spacing: 10) {
                    Image("PR_empty_icon").resizable().frame(width: 100, height: 100)
                    Text("No Content").font(.semibold15).foregroundColor(Color(hex: "#141414"))
                    Text("Perfect！You can go and clean other categories.")
                        .font(.regular14).foregroundColor(Color(hex: "#A3A3A3")).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }else{
                bottomBar
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            PRCustomNavBar(
                backAction: { appRouterPath.back() },
                title: headerTitle,
                titleOpacity: min(max(scrollOffsetY / navTitleRevealHeight, 0), 1),
                toggleAll: {
                    withAnimation(nil) {
                        if allSelected { selectedIDs.removeAll() }
                        else { selectedIDs = Set(flatModels.map { $0.photoIdentifier }) }
                        recalcSelectedBytes() // ✅ 直接用 model.bytes 相加
                    }
                },
                allSelected: allSelected,
                showToggleAll: !flatModels.isEmpty
            )
            .zIndex(1)
        }
        .onAppear {
            refreshData(initial: true)
            subscribeScoped()
        }
        .onDisappear { cancellable?.cancel() }
        .onChange(of: selectedIDs) { _ in recalcSelectedBytes() } // ✅ 改同步求和
    }

    // MARK: - 子视图

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerTitle).font(.heavy24).foregroundColor(Color(hex: "#141414")).padding(.top, 0)
            Text("Disorderly content: \(totalDisorderCount)").font(.regular12).foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).frame(height: 44).background(.white)
    }

    private func groupSection(section: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                let items = doubleModels[section]
                Text("\(items.count) \(vcellSuffix)")
                    .font(.bold16).foregroundColor(Color(hex: "#141414"))
                Spacer()
                Button(isSectionAllSelected(section) ? "Deselect All" : "Select All") {
                    toggleSectionSelection(section)
                }
                .font(.regular14)
                .foregroundColor(Color(hex: "#A3A3A3"))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(doubleModels[section], id: \.photoIdentifier) { model in
                        HCell(
                            model: model,
                            isSelected: selectedIDs.contains(model.photoIdentifier),
                            isBest: doubleModels[section].first?.photoIdentifier == model.photoIdentifier,
                            // ✅ 使用统一的缩略图 Provider + 通过 manager.fetchOrResolvePHAsset 懒解析
                            thumbProvider: thumbProvider
                        ) {
                            toggle(model)
                            recalcSelectedBytes()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 213)

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity).frame(height: 273)
    }

    private var bottomBar: some View {
        ZStack {
            Color.white.ignoresSafeArea(edges: .bottom) // 纯白背景，延伸到底部安全区
            HStack {
                PRThemeButton(title: bottomTitle, enable: !selectedIDs.isEmpty, type: .delete) {
                    guard !selectedIDs.isEmpty else { return }
                    let delIDs = selectedIDs
                    let selectedSize = selectedBytes

                    PRAssetsHelper.shared.purgeResourcesWithPrivilegeVerification(
                        [],                               // 传空 assets，内部用 id 解析
                        assetIDs: Array(delIDs),          // ✅ 传入待删 ID
                        uiState: uiState,
                        paySource: .deleteFunc,
                        from: cardID
                    ) { result in
                        switch result {
                        case .success:
                            Task { @MainActor in
                                // 乐观刷新
                                let delSet = delIDs
                                doubleModels = doubleModels
                                    .map { group in group.filter { !delSet.contains($0.photoIdentifier) } }
                                    .filter { !$0.isEmpty }
                                selectedIDs.subtract(delSet)
                                selectedBytes = 0

//                                let storageSize = await AlbumFileMananger.shared.storageUsageByte()
                                let deletedText = checkFormatBytes(selectedSize)
                                uiState.fullScreenCoverDestination = .exploreDeleteFinish(
                                    count: Int64(delSet.count),
                                    deletedText: deletedText,
                                    storageSize: 0, //Int64(storageSize),
                                    onDismiss: { uiState.fullScreenCoverDestination = nil }
                                )
                            }
                        case .failure:
                            break
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, max(22, DeviceHelper.safeAreaInsets.bottom)) // 底部留点手势/安全区空间
        }
        .frame(height: 90)
    }

    private var bottomTitle: String {
        if selectedIDs.isEmpty { return "Delete" }
        return "Delete (\(checkFormatBytes(selectedBytes)))"
    }
}

// MARK: - 自定义导航条（保持原有样式）

private struct PRCustomNavBar: View {
    let backAction: () -> Void
    let title: String
    let titleOpacity: CGFloat
    let toggleAll: () -> Void
    let allSelected: Bool
    let showToggleAll: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Image("icon_nav_return")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }

            Text(title)
                .font(.semibold20)
                .foregroundColor(Color(hex: "#141414"))
                .opacity(titleOpacity)

            Spacer()

            if showToggleAll {
                Button(action: toggleAll) {
                    Text(allSelected ? "Deselect all" : "Select all")
                        .font(.regular15)
                        .foregroundColor(Color(hex: "#141414"))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - 业务逻辑

private extension PRDuplicatePage {
    /// 读取 manager 中的 [[PRPhotoAssetModel]]，并按需要做默认勾选
    func refreshData(initial: Bool = false) {
        let m = PRPhotoMapManager.shared
        let newDouble: [[PRPhotoAssetModel]]
        switch cardID {
        case "similarphoto":   newDouble = m.similarPhotosMap.doubleAssets
        case "duplicatephoto": newDouble = m.duplicatePhotosMap.doubleAssets
        case "similarvideo":   newDouble = m.similarVideosMap.doubleAssets
        default:               newDouble = []
        }
        doubleModels = newDouble

        if initial {
            // 默认选中每组“除第一张外”的全部
            var set = Set<String>()
            for group in newDouble {
                for (idx, m) in group.enumerated() where idx > 0 { set.insert(m.photoIdentifier) }
            }
            selectedIDs = set
            recalcSelectedBytes()
        } else {
            // 仅保留仍存在于新结果中的选中项
            let alive = Set(newDouble.flatMap { $0.map(\.photoIdentifier) })
            selectedIDs = selectedIDs.intersection(alive)
            recalcSelectedBytes()
        }
    }

    func isSectionAllSelected(_ section: Int) -> Bool {
        guard doubleModels.indices.contains(section) else { return false }
        let ids = Set(doubleModels[section].map(\.photoIdentifier))
        return !ids.isEmpty && ids.isSubset(of: selectedIDs)
    }

    func toggleSectionSelection(_ section: Int) {
        guard doubleModels.indices.contains(section) else { return }
        let ids = Set(doubleModels[section].map(\.photoIdentifier))
        if ids.isSubset(of: selectedIDs) { selectedIDs.subtract(ids) }
        else { selectedIDs.formUnion(ids) }
    }

    func toggle(_ model: PRPhotoAssetModel) {
        let id = model.photoIdentifier
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    /// ✅ 同步计算选择字节：直接 sum PRPhotoAssetModel.photoBytes
    func recalcSelectedBytes() {
        guard !selectedIDs.isEmpty else { selectedBytes = 0; return }
        let idx = Set(selectedIDs)
        let total = doubleModels
            .flatMap { $0 }
            .filter { idx.contains($0.photoIdentifier) }
            .reduce(Int64(0)) { $0 &+ $1.photoBytes }
        selectedBytes = total
    }

    /// 仅订阅当前需要的分组 Map
    func subscribeScoped() {
        let pub: AnyPublisher<PRPhotoAssetsMap, Never>
        switch cardID {
        case "similarphoto":   pub = manager.$similarPhotosMap.eraseToAnyPublisher()
        case "duplicatephoto": pub = manager.$duplicatePhotosMap.eraseToAnyPublisher()
        case "similarvideo":   pub = manager.$similarVideosMap.eraseToAnyPublisher()
        default:               return
        }
        cancellable = pub
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { _ in self.refreshData() }
    }
}

// MARK: - 单元格（缩略图由统一 Provider 提供；PHAsset 懒解析）

private struct HCell: View {
    let model: PRPhotoAssetModel
    let isSelected: Bool
    let isBest: Bool
    let thumbProvider: PRAssetThumbnailProvider
    let toggle: () -> Void
    private let corner: CGFloat = 16

    var body: some View {
        // 运行期解析 PHAsset（内部有 NSCache；无则显示占位）
        let asset = PRPhotoMapManager.shared.resolveAssetEntity(for: model.photoIdentifier)

        ZStack(alignment: .bottomTrailing) {
            if let a = asset {
                thumbProvider.constructVisualElement(
                    for: a,
                    targetSize: CGSize(width: 140.fit, height: 140.fit),
                    preferFastFirst: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                // 没解析到时的兜底占位（iCloud 未本地化、权限变化等）
                Rectangle().fill(Color(hex: "#F2F2F2"))
                    .overlay(
                        VStack(spacing: 8) {
                            ProgressView().progressViewStyle(.circular)
                            Text("Loading…").font(.regular12).foregroundColor(.secondary)
                        }
                    )
            }
        }
        .frame(width: 148.fit, height: 148.fit)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Image(isSelected ? "icon_photo_selected" : "icon_photo_normal")
                .resizable().frame(width: 24, height: 24).padding(8).allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if isBest {
                Image("ic_best")
                    .resizable()
                    .frame(width: 78, height: 20)
            }
        }
        .compositingGroup().contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .onTapGesture { toggle() }
    }
}
