//
//  AssetsHelper.swift

//
//

import Photos
import UIKit

extension PRAssetsHelper {

    /// 删除资产（需要 VIP 权限），支持传入现有 `PHAsset` 或 `localIdentifier` 数组
    public func removeAssetsWithVipCheck(
        _ assets: [PHAsset],
        assetIDs: [String]? = nil,
        uiState: PRUIState,
        paySource: PaySource = .guided,
        from: String = "",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let finalAssets: [PHAsset] = {
            if !assets.isEmpty { return assets }
            if let ids = assetIDs, !ids.isEmpty { return retrievePHAssets(by: ids) }
            return []
        }()

        guard !finalAssets.isEmpty else {
            completion(.success(()))
            return
        }

//        StatisticsManager.log(name: "JHQ_001", params: ["from": from])

        if !PRUserManager.shared.isVip() {
            Task { @MainActor in
                uiState.fullScreenCoverDestination = .subscription(
                    paySource: paySource,
                    onDismiss: { isSuccess in
                        uiState.fullScreenCoverDestination = nil
                        if isSuccess {
                            self.performAssetDeletion(finalAssets, from: from, completion: completion)
                        } else {
                            completion(.failure(PRAssetsExecError.requestCancelled))
                        }
                    }
                )
            }
        } else {
            performAssetDeletion(finalAssets, from: from, completion: completion)
        }
    }
}

/// 资产工具集合：缩略图加载与批量删除
class PRAssetsHelper {
    
    public static let shared = PRAssetsHelper()
    
    /// 加载高清缩略图（允许 iCloud 下载，屏蔽降质结果）
    func fetchHighQualityThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    ) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = deliveryMode
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }
                
                guard let image = image else {
                    continuation.resume(throwing: PRAssetsExecError.imageNotFound)
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    /// 加载快速缩略图（不走网络，首帧快）
    func fetchFastThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let image = image else {
                    continuation.resume(throwing: PRAssetsExecError.imageNotFound)
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    /// 并发加载缩略图（自动聚合结果）
    func fetchMultipleThumbnails(
        for assets: [PHAsset],
        targetSize: CGSize = CGSize(width: 200, height: 200),
        useFaseter: Bool = false,
        faster: Bool = false
    ) async throws -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
            for asset in assets {
                group.addTask {
                    var image: UIImage
                    if faster {
                        image = try await self.fetchFastThumbnail(for: asset, targetSize: targetSize)
                    } else {
                        image = try await self.fetchHighQualityThumbnail(for: asset, targetSize: targetSize)
                    }
                    return (asset.localIdentifier, image)
                }
            }
            
            for try await (assetID, image) in group {
                results[assetID] = image
            }
        }
        
        return results
    }
    
    /// 限并发批量加载缩略图（分块）
    func fetchThumbnailsWithLimit(
        for assets: [PHAsset],
        targetSize: CGSize = CGSize(width: 200, height: 200),
        maxConcurrentTasks: Int = 4,
        faster: Bool = false
    ) async throws -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        let assetChunks = assets.chunked(into: maxConcurrentTasks)
        
        for chunk in assetChunks {
            try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
                for asset in chunk {
                    group.addTask {
                        var image: UIImage
                        if faster {
                            image = try await self.fetchFastThumbnail(for: asset, targetSize: targetSize)
                        } else {
                            image = try await self.fetchHighQualityThumbnail(for: asset, targetSize: targetSize)
                        }
                        return (asset.localIdentifier, image)
                    }
                }
                
                for try await (assetID, image) in group {
                    results[assetID] = image
                }
            }
        }
        
        return results
    }
    
    /// 执行删除（已授权）
    private func performAssetDeletion(_ assets: [PHAsset], from: String, completion: @escaping (Result<Void, Error>) -> Void) {
        
        guard !assets.isEmpty else {
            completion(.success(()))
            return
        }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            completion(.failure(PRAssetsExecError.authorizationDenied))
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }) { success, error in
//            StatisticsManager.log(name: "JHQ_002", params: ["from": from])
            DispatchQueue.main.async {
                if success {
                    PRPhotoMapManager.shared.lastDeleteAssets = assets
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? PRAssetsExecError.unknown))
                }
            }
        }
    }
}

enum PRAssetsExecError: Error, LocalizedError {
    case imageNotFound
    case authorizationDenied
    case requestCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .imageNotFound:
            return "imageNotFound"
        case .authorizationDenied:
            return "authorizationDenied"
        case .requestCancelled:
            return "requestCancelled"
        case .unknown:
            return "unknown"
        }
    }
}
