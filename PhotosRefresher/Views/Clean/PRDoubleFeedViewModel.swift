//
//  PRDoubleFeedViewModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos

final class PRDoubleFeedViewModel: ObservableObject {
    @Published var assets: [PHAsset] = []
    @Published var selectedIDs: Set<String> = []
    @Published var isDeleting: Bool = false
    @Published var selectedBytes: Int64 = 0

    private(set) var isBound = false
    private weak var uiState: PRUIState?
    var currentCardID: String = ""

    /// 当前页面用于直加字节的索引：id -> model
    private var modelIndex: [String: PRAssetsAnalyzeResult] = [:]

    func bind(uiState: PRUIState) async {
        guard !isBound else { return }
        self.uiState = uiState
        isBound = true
    }

    func loadAssets(cardID: PRAssetType) {
        currentCardID = cardID.rawValue

        // 1) 取得当前类目的 map，并建立 id->model 的索引
        let map = mapFromManager(cardID)
        modelIndex = Dictionary(uniqueKeysWithValues: map.assets.map { ($0.assetIdentifier, $0) })

        // 2) 根据 id 列表解析 PHAsset（仅用于显示）
        let newAssets = fetchAssetEntities(by: map.localIdentifiers)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.assets = newAssets
            self.selectedIDs = Set(newAssets.map { $0.localIdentifier }) // 默认全选
            self.recalcSelectedBytes()
        }
    }

    private func mapFromManager(_ cardID: PRAssetType) -> PRAssetsInfo {
        let m = PRAssetsCleanManager.shared
        switch cardID {
        case .PhotosScreenshot:     return m.assetsInfoForScreenShot
        case .PhotosLive:      return m.assetsInfoForLivePhoto
        case .VideoAll:       return m.assetsInfoForVideo
        case .PhotosBlurry:    return m.assetsInfoForBlurry
        case .PhotosText:      return m.assetsInfoForTextPhotos
        case .VideoLarge:     return m.assetsInfoForLargeVideo
        case .selfiephoto:    return m.assetsInfoForSelfiePhotos
        case .backphoto:      return m.assetsInfoForBackPhotos
        case .PhotosSimilar:
            // 展平分组为单列表，便于选择/删除
            var map = PRAssetsInfo(.PhotosSimilar)
            map.assets = m.assetsInfoForSimilar.groupAssets.flatMap { $0 }
            map.bytes = map.assets.reduce(0) { $0 &+ $1.storageSize }
            return map
        case .PhotosDuplicate:
            var map = PRAssetsInfo(.PhotosDuplicate)
            map.assets = m.assetsInfoForDuplicate.groupAssets.flatMap { $0 }
            map.bytes = map.assets.reduce(0) { $0 &+ $1.storageSize }
            return map
//        default:
//            return PRPhotoAssetsMap(.screenshot)
        }
    }

    func toggleSelection(_ asset: PHAsset, isSelected: Bool) {
        if isSelected { selectedIDs.insert(asset.localIdentifier) }
        else { selectedIDs.remove(asset.localIdentifier) }
        recalcSelectedBytes()
    }

    func selectAllOrClear() {
        if selectedIDs.count == assets.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(assets.map { $0.localIdentifier })
        }
        recalcSelectedBytes()
    }

    /// 直接用 photoBytes 聚合（O(n)）
    private func recalcSelectedBytes() {
        var total: Int64 = 0
        for id in selectedIDs {
            if let m = modelIndex[id] { total &+= m.storageSize }
        }
        selectedBytes = total
    }

    // MARK: - 删除 & 刷新

    func deleteSelected(completion: @escaping (Bool, String, Int64, Int64) -> Void) {
        guard !selectedIDs.isEmpty else {
            completion(false, "还没有勾选哟", 0, 0)
            return
        }
        isDeleting = true

        let idsToDelete = selectedIDs
        let assetsToDelete = assets.filter { idsToDelete.contains($0.localIdentifier) }
        let selectedCount = Int64(idsToDelete.count)
        let selectedSize  = selectedBytes

        PRAssetsHelper.shared.purgeResourcesWithPrivilegeVerification(
            assetsToDelete,
            assetIDs: Array(idsToDelete),                     // 新签名：传入 id 兜底
            uiState: uiState ?? PRUIState.shared,
            from: currentCardID
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                Task { @MainActor in
                    self.isDeleting = false
                    self.applyLocalDeletion(idsToDelete)
                }
                completion(true, "", selectedCount, selectedSize)
            case .failure:
                Task { @MainActor in self.isDeleting = false }
                completion(false, "", 0, 0)
            }
        }
    }

    private func applyLocalDeletion(_ ids: Set<String>) {
        assets.removeAll { ids.contains($0.localIdentifier) }
        selectedIDs.removeAll()
        selectedBytes = 0
    }
}
