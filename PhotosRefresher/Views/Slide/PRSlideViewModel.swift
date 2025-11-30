//
//  PRSlideViewModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Combine
import Photos

class PRSlideViewModel: ObservableObject {
    
    @Published var currentCategory: PRAssetType = PRAppUserPreferences.shared.currentSlideCategory {
        didSet {
            previewFive = []
            prepareSet()
        }
    }
    
    @Published var previewFive: [PHAsset] = []
    

    private var manager: PRAssetsCleanManager { .shared }
    private let cache = PRSlideCacheManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        PRAppUserPreferences.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newCat = PRAppUserPreferences.shared.currentSlideCategory
                if newCat != self.currentCategory {
                    self.currentCategory = newCat
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .slideSessionDidAdvance)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                if let raw = note.userInfo?["category"] as? String,
                   let cat = PRAssetType(rawValue: raw),
                   cat == self.currentCategory,
                   let nextIDs = note.userInfo?["nextIDs"] as? [String] {
                    let first5IDs = Array(nextIDs.prefix(5))
                    let first5 = fetchAssetEntities(by: first5IDs)
                    self.previewFive = first5
                }
            }
            .store(in: &cancellables)
        
    }

    var hasPermission: Bool {
        switch PRAppUserPreferences.shared.galleryPermissionState {
        case .authorized, .limited: return true
        case .notDetermined: return true
        default: return false
        }
    }

    func loadCategory(_ cat: PRAssetType) {
        currentCategory = cat
        PRAppUserPreferences.shared.currentSlideCategory = cat
    }

    func prepareSet() {
        let ids = mapFor(currentCategory).localIdentifiers
        guard !ids.isEmpty else {
            
            previewFive = []
            return
        }
        
        let first5IDs = cache.unviewedFirst(limit: 5, category: currentCategory, sourceIDs: ids)
        let first5 = fetchAssetEntities(by: first5IDs)
        previewFive = first5
    }

    func layoutNeighbors(center: Int, in all: [PHAsset]) -> [PHAsset] {
        guard !all.isEmpty else { return [] }
        func at(_ i: Int) -> PHAsset? { (i >= 0 && i < all.count) ? all[i] : nil }
        var res: [PHAsset] = []
        if let c = at(center) { res.append(c) }
        if let a = at(center-1) { res.append(a) }
        if let b = at(center+1) { res.append(b) }
        if let c2 = at(center-2) { res.append(c2) }
        if let d2 = at(center+2) { res.append(d2) }
        return res
    }

    
    func mapFor(_ cat: PRAssetType) -> PRAssetsInfo {
        switch cat {
        case .PhotosScreenshot: return manager.assetsInfoForScreenShot
        case .PhotosLive: return manager.assetsInfoForLivePhoto
        case .selfiephoto: return manager.assetsInfoForSelfiePhotos
        case .backphoto: return manager.assetsInfoForBackPhotos
        default: return manager.assetsInfoForBackPhotos
        }
    }

    var alternativeCategories: [PRAssetType] {
        let all: [PRAssetType] = [.PhotosScreenshot, .selfiephoto, .PhotosLive, .backphoto]
        return all.filter { $0 != currentCategory }
    }
}
