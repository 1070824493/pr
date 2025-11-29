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
    
    @Published var currentCategory: PRPhotoCategory = PRAppUserPreferences.shared.currentSlideCategory {
        didSet {
            previewFive = []
            prepareSet()
        }
    }
    
    @Published var previewFive: [PHAsset] = []
    

    private var manager: PRPhotoMapManager { .shared }
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
                   let cat = PRPhotoCategory(rawValue: raw),
                   cat == self.currentCategory,
                   let nextIDs = note.userInfo?["nextIDs"] as? [String] {
                    let first5IDs = Array(nextIDs.prefix(5))
                    let first5 = retrievePHAssets(by: first5IDs)
                    self.previewFive = first5
                }
            }
            .store(in: &cancellables)
        
    }

    var hasPermission: Bool {
        switch PRAppUserPreferences.shared.albumPermissionStatus {
        case .authorized, .limited: return true
        case .notDetermined: return true
        default: return false
        }
    }

    func loadCategory(_ cat: PRPhotoCategory) {
        currentCategory = cat
        PRAppUserPreferences.shared.currentSlideCategory = cat
    }

    func prepareSet() {
        let ids = mapFor(currentCategory).assetIDs
        guard !ids.isEmpty else {
            
            previewFive = []
            return
        }
        
        let first5IDs = cache.unviewedFirst(limit: 5, category: currentCategory, sourceIDs: ids)
        let first5 = retrievePHAssets(by: first5IDs)
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

    
    func mapFor(_ cat: PRPhotoCategory) -> PRPhotoAssetsMap {
        switch cat {
        case .screenshot: return manager.screenshotPhotosMap
        case .livePhoto: return manager.livePhotosMap
        case .selfiephoto: return manager.selfiePhotosMap
        case .backphoto: return manager.backPhotosMap
        default: return manager.backPhotosMap
        }
    }

    var alternativeCategories: [PRPhotoCategory] {
        let all: [PRPhotoCategory] = [.screenshot, .selfiephoto, .livePhoto, .backphoto]
        return all.filter { $0 != currentCategory }
    }
}
