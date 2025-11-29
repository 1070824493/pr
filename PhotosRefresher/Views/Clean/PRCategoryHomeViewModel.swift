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
    @Published private(set) var snapshots: [PRPhotoCategory: CategoryItemVM] = [:]
    @Published var disk: PRDiskSpace? = nil

    let order: [PRPhotoCategory] = [
        .allvideo,
        .screenshot,
        .livePhoto,
        .similarphoto,
        .duplicatephoto,
        .largevideo,
        .blurryphoto,
        .textphoto
    ]

    private let manager: PRPhotoMapManager
    private var bag = Set<AnyCancellable>()
    private var assetCache: [String: PHAsset] = [:]

    init(manager: PRPhotoMapManager = .shared) {
        self.manager = manager
        bind()
        Task.detached(priority: .utility) { [weak self] in
            let d = retrieveDiskSpaceInfo()
            await MainActor.run { self?.disk = d }
        }
    }

    private func bind() {
        manager.$dashboard
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dash in
                guard let self, let dash = dash else { return }

                self.totalCleanable = dash.totalSize
                var out: [PRPhotoCategory: CategoryItemVM] = [:]
                
                let validIDs = dash.cells
                    .compactMap({$0.repID}).reduce(into: []) { partialResult, ids in
                        return partialResult += ids
                    }
                
                self.assetCache = self.assetCache.filter { key, value in
                    validIDs.contains(key)
                }

                for cell in dash.cells {

                    let assets = cell.repID.compactMap { id in
                        if let cached = self.assetCache[id] {
                            return cached
                        } else if let newA = self.manager.fetchOrResolvePHAsset(for: id) {
                            self.assetCache[id] = newA
                            return newA
                        }
                        return nil
                    }

                    out[cell.category] = CategoryItemVM(
                        category: cell.category,
                        bytes: cell.bytes,
                        repID: cell.repID,
                        repAsset: assets,
                        totalCount: cell.count
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
        manager.reloadAllAssetsAndRestartPipeline()
    }
}
