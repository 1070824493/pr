//
//  PRDoubleFeedPage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos
import Combine

// MARK: - Byte format

private func checkFormatBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 KB" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    var v = Double(bytes)
    var i = 0
    while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
    return (v >= 10 || i == 0) ? String(format: "%.0f %@", v, units[i])
                                : String(format: "%.1f %@", v, units[i])
}



// MARK: - Cell View（统一使用 PRAssetThumbnailProvider）

private struct PRExploreCellView: View {
    let asset: PHAsset
    let size: CGSize
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let thumbProvider: PRAssetThumbnailProvider

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            thumbProvider
                .createThumbnailView(for: asset, targetSize: size, preferFastFirst: true)
                .frame(width: size.width, height: size.height)
                .clipped()
                .cornerRadius(12)

            Button(action: { onToggle(!isSelected) }) {
                Image(isSelected ? "icon_photo_selected" : "icon_photo_normal")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle(!isSelected) }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Custom Nav Bar

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
        .background(Color.white.ignoresSafeArea()) // 关键：让导航背景延伸
    }
}

// MARK: - Header / Bottom Bar

private struct PRFeedHeaderView: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.heavy24).foregroundColor(Color(hex: "#141414"))
            Text(subtitle).font(.regular12).foregroundColor(Color(hex: "#666666"))
        }
        .padding(.horizontal, 16).padding(.top, 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .background(Color.white)
    }
}

private struct PRBottomBar: View {
    let enabled: Bool
    let bytes: Int64
    let deleteAction: () -> Void
    var body: some View {
        PRThemeButton(title: enabled ? "Delete (\(checkFormatBytes(bytes)))" : "Delete", enable: enabled, type: .delete, action:  {
            if enabled {
                deleteAction()
            }
        })
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(height: 56)
        .background(Color.white)
    }
}


/// 两列的图片展示页面
struct PRDoubleFeedPage: View {
    let cardID: PRPhotoCategory
    @EnvironmentObject var appRouterPath: PRAppRouterPath
    @EnvironmentObject private var uiState: PRUIState
    var isVideo: Bool = false
    @StateObject private var vm = PRDoubleFeedViewModel()
    @State private var scrollY: CGFloat = 0

    /// 页面级缩略图 Provider（非单例，便于测试与注入）
    private let thumbProvider = PRAssetThumbnailProvider()

    init(_ cardID: PRPhotoCategory, isVideo: Bool = false) {
        self.cardID = cardID
        self.isVideo = isVideo
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8),
         GridItem(.flexible(), spacing: 8)]
    }

    private var navTitle: String { texts(for: cardID).navTitle }
    private var headerTitle: String { texts(for: cardID).headerTitle }
    private var headerSubtitle: String { texts(for: cardID).headerSubtitle }

    private func texts(for id: PRPhotoCategory) -> (navTitle: String, headerTitle: String, headerSubtitle: String) {
        switch id {
        case .screenshot: return ("Screenshots", "Screenshots", "Disorderly content: \(vm.assets.count)")
        case .livePhoto:    return ("Live Photos", "Live Photos", "Disorderly content: \(vm.assets.count)")
        case .allvideo:     return ("All Videos", "All Videos", "Disorderly content: \(vm.assets.count)")
        case .similarphoto: return ("Similar Photos", "Similar Photos", "Disorderly content: \(vm.assets.count)")
        case .blurryphoto:  return ("Blurry Photos", "Blurry Photos", "Disorderly content: \(vm.assets.count)")
        case .duplicatephoto: return ("Duplicate Photos", "Duplicate Photos", "Disorderly content: \(vm.assets.count)")
        case .textphoto:    return ("Text Photos", "Text Photos", "Disorderly content: \(vm.assets.count)")
        case .largevideo:   return ("Large Videos", "Large Videos", "Disorderly content: \(vm.assets.count)")
        case .similarvideo: return ("Similar Videos", "Similar Videos", "Disorderly content: \(vm.assets.count)")
        default:             return ("Library", "Your Library", "Select items to delete. Long press to preview.")
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    PRFeedHeaderView(title: headerTitle, subtitle: headerSubtitle)
                        .padding(.bottom, 10)

                    LazyVGrid(columns: gridColumns, alignment: .center, spacing: 8) {
                        let cellW = (UIScreen.main.bounds.width - 16 * 2 - 8) / CGFloat(gridColumns.count)
                        let cellH: CGFloat = isVideo ? cellW : 213
                        ForEach(Array(vm.assets.enumerated()), id: \.1.localIdentifier) { (idx, asset) in
                            let isSelected = vm.selectedIDs.contains(asset.localIdentifier)
                            PRExploreCellView(
                                asset: asset,
                                size: CGSize(width: cellW, height: cellH),
                                isSelected: isSelected,
                                onToggle: { newState in vm.toggleSelection(asset, isSelected: newState) },
                                thumbProvider: thumbProvider
                            )
                            .onAppear {
                                // 预热后续 24 张（像素上限 256，避免过度显存）
                                let end = min(idx + 24, vm.assets.count)
                                if idx < end {
                                    let next = Array(vm.assets[idx..<end])
                                    let scale = UIScreen.main.scale
                                    let px = CGSize(width: min(cellW * scale, 256 * scale),
                                                    height: min(cellH * scale, 256 * scale))
                                    thumbProvider.startPreheatingAssets(assets: next, pixelSize: px)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }

            if vm.assets.isEmpty {
                VStack(spacing: 10) {
                    Image("PR_empty_icon").resizable().frame(width: 100, height: 100)
                    Text("No Content").font(.semibold15).foregroundColor(Color(hex: "#141414"))
                    Text("Perfect！You can go and clean other categories.")
                        .font(.regular14).foregroundColor(Color(hex: "#A3A3A3")).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !vm.assets.isEmpty {
                PRBottomBar(
                    enabled: !vm.selectedIDs.isEmpty && !vm.isDeleting,
                    bytes: vm.selectedBytes,
                    deleteAction: {
                        vm.deleteSelected { isSuccess, _, count, size in
                            if isSuccess {
                                Task {
//                                    let storageSize = await AlbumFileMananger.shared.storageUsageByte()
                                    let deletedText = checkFormatBytes(size)
                                    await MainActor.run {
                                        uiState.fullScreenCoverDestination = .exploreDeleteFinish(
                                            count: count,
                                            deletedText: deletedText,
                                            storageSize: 0, //Int64(storageSize),
                                            onDismiss: { uiState.fullScreenCoverDestination = nil }
                                        )
                                    }
                                }
                            }
                        }
                    }
                )
            } else {
                EmptyView()
            }
        }
        .safeAreaInset(edge: .top) {
            PRCustomNavBar(
                backAction: { appRouterPath.back() },
                title: navTitle,
                titleOpacity: min(max(scrollY / 64.0, 0), 1),
                toggleAll: { vm.selectAllOrClear() },
                allSelected: vm.selectedIDs.count == vm.assets.count && !vm.assets.isEmpty,
                showToggleAll: !vm.assets.isEmpty
            )
            .background(Color.white.ignoresSafeArea(edges: .top))
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await vm.bind(uiState: uiState)
            vm.loadAssets(cardID: cardID)
        }
    }
}


