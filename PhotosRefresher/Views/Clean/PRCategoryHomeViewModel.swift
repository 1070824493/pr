//
//  PRCategoryHomeViewModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos
import Combine


final class PRCategoryHomeViewModel: ObservableObject {
    @Published private(set) var totalCleanable: Int64 = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var snapshots: [PRAssetType: CategoryItemVM] = [:]
    @Published var disk: PRDiskSpace? = nil

    let order: [PRAssetType] = [
        .VideoAll,
        .PhotosScreenshot,
        .PhotosLive,
        .PhotosSimilar,
        .PhotosDuplicate,
        .VideoLarge,
        .PhotosBlurry,
        .PhotosText
    ]

    private let manager: PRAssetsCleanManager
    private var bag = Set<AnyCancellable>()
    private var assetCache: [String: PHAsset] = [:]

    init(manager: PRAssetsCleanManager = .shared) {
        self.manager = manager
        bind()
        Task.detached(priority: .utility) { [weak self] in
            let d = assessStorageMetrics()
            await MainActor.run { self?.disk = d }
        }
    }

    private func bind() {
        manager.$snap
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dash in
                guard let self, let dash = dash else { return }

                self.totalCleanable = dash.aggregateSize
                var out: [PRAssetType: CategoryItemVM] = [:]
                
                let validIDs = dash.cellCollectioncellCollection
                    .compactMap({$0.previewIdentifiers}).reduce(into: []) { partialResult, ids in
                        return partialResult += ids
                    }
                
                self.assetCache = self.assetCache.filter { key, value in
                    validIDs.contains(key)
                }

                for cell in dash.cellCollectioncellCollection {

                    let assets = cell.previewIdentifiers.compactMap { id in
                        if let cached = self.assetCache[id] {
                            return cached
                        } else if let newA = self.manager.resolveAssetEntity(for: id) {
                            self.assetCache[id] = newA
                            return newA
                        }
                        return nil
                    }

                    out[cell.classification] = CategoryItemVM(
                        category: cell.classification,
                        bytes: cell.storageUsage,
                        repID: cell.previewIdentifiers,
                        repAsset: assets,
                        totalCount: cell.elementCount
                    )
                }
                self.snapshots = out
            }
            .store(in: &bag)

        manager.$state
            .map { s -> Bool in
                if case .idle = s { return false } else { return true }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
    }

    func ensureStartedIfAllowed() {
        manager.refreshAssetRepositoryAndInitiateSequence()
    }
}
