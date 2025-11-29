//
//  PRAssetThumbnailProvider.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import SwiftUI
import Photos

// MARK: - 内存缓存（像素级，避免滚动闪动）
final class PRThumbnailStorage {
    static let shared = PRThumbnailStorage()
    let storage = NSCache<NSString, UIImage>()
    private init() {
        storage.countLimit = 600
        storage.totalCostLimit = 160 * 1024 * 1024 // ~160MB，可按机型调
    }
    func generateCacheKey(for identifier: String, dimensions: CGSize, delivery: PHImageRequestOptionsDeliveryMode) -> NSString {
        NSString(string: "\(identifier)_\(Int(dimensions.width))x\(Int(dimensions.height))_\(delivery.rawValue)")
    }
    func clearAllCache() { storage.removeAllObjects() }
}

// MARK: - 单张缩略图 Loader
/// 单张缩略图 Loader（两段式加载）
private final class PRAssetThumbLoader: ObservableObject {
    @Published var displayImage: UIImage?
    private var loadingTask: Task<Void, Never>?

    /// 加载指定资产缩略图（优先显示缓存/快速图，随后替换为高清图）
    func initiateImageAcquisition(asset: PHAsset, targetSize: CGSize, preferFast: Bool) {
        let imageCache = PRThumbnailStorage.shared
        let fastCacheKey = imageCache.generateCacheKey(for: asset.localIdentifier, dimensions: targetSize, delivery: .fastFormat)
        let qualityCacheKey = imageCache.generateCacheKey(for: asset.localIdentifier, dimensions: targetSize, delivery: .highQualityFormat)

        // 命中缓存先显示
        if let cachedImage = imageCache.storage.object(forKey: fastCacheKey) { self.displayImage = cachedImage }
        else if let cachedImage = imageCache.storage.object(forKey: qualityCacheKey) { self.displayImage = cachedImage }

        loadingTask?.cancel()
        loadingTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let selfReference = self else { return }
            do {
                // 先快图：不走网络，首帧快
                if preferFast || selfReference.displayImage == nil {
                    if !Task.isCancelled {
                        let fastImage = try await PRAssetsHelper.shared.acquireRapidImage(
                            for: asset,
                            targetSize: CGSize(width: targetSize.width * 2, height: targetSize.height * 2)
                        )
                        let memoryCost = max(1, Int(targetSize.width * targetSize.height) * 4)
                        imageCache.storage.setObject(fastImage, forKey: fastCacheKey, cost: memoryCost)
                        await MainActor.run { if selfReference.displayImage == nil { selfReference.displayImage = fastImage } }
                    }
                }
                // 再高清：若需要 iCloud 下载则退避（PRAssetsHelper 内部已处理）
                if !Task.isCancelled {
                    let qualityImage = try await PRAssetsHelper.shared.acquireHighFidelityImage(
                        for: asset,
                        targetSize: CGSize(width: targetSize.width * 2, height: targetSize.height * 2),
                        deliveryMode: .highQualityFormat
                    )
                    let memoryCost = max(1, Int(targetSize.width * targetSize.height) * 4)
                    imageCache.storage.setObject(qualityImage, forKey: qualityCacheKey, cost: memoryCost)
                    await MainActor.run {
                        // 仅在更清晰时替换，降低抖动
                        if selfReference.displayImage?.size != qualityImage.size { selfReference.displayImage = qualityImage }
                    }
                }
            } catch {
                // 静默失败：保留已有图或占位
            }
        }
    }

    deinit { loadingTask?.cancel() }
}

// MARK: - SwiftUI 包装视图
/// SwiftUI 缩略图视图包装
private struct PRAssetThumbnailView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let placeholder: Image
    let preferFastFirst: Bool

    @StateObject private var imageLoader = PRAssetThumbLoader()
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            if let loadedImage = imageLoader.displayImage {
                Image(uiImage: loadedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledToFill()
                .transition(.opacity.combined(with: .scale(scale: 0.995)))
            } else {
                placeholder.resizable().scaledToFill().opacity(0.35)
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            imageLoader.initiateImageAcquisition(asset: asset, targetSize: targetSize, preferFast: preferFastFirst)
        }
        .onChange(of: asset.localIdentifier) { _ in
            imageLoader.initiateImageAcquisition(asset: asset, targetSize: targetSize, preferFast: preferFastFirst)
        }
        .clipped()
    }
}

// MARK: - 对外 Provider（可实例化；内部共享缓存）
/// 缩略图 Provider（带像素缓存与预热）
public final class PRAssetThumbnailProvider {

    private let cachingManager = PHCachingImageManager()

    public init() {}

    /// SwiftUI 友好的缩略图视图（带缓存 & 防闪动 & 退避策略）
    public func constructVisualElement(
        for asset: PHAsset,
        targetSize: CGSize,
        placeholder: Image = Image("PR_deaultImage"),
        preferFastFirst: Bool = true
    ) -> some View {
        PRAssetThumbnailView(
            asset: asset,
            targetSize: targetSize,
            placeholder: placeholder,
            preferFastFirst: preferFastFirst
        )
    }

    /// 批量预热（建议在列表滚动 onAppear 里对后续 12~24 张调用）
    public func initiateResourceWarming(assets: [PHAsset], pixelSize: CGSize) {
        guard !assets.isEmpty else { return }
        let requestConfiguration = PHImageRequestOptions()
        requestConfiguration.deliveryMode = .highQualityFormat
        requestConfiguration.resizeMode = .fast
        requestConfiguration.isSynchronous = false
        requestConfiguration.isNetworkAccessAllowed = false // 预热不触发网络
        cachingManager.startCachingImages(for: assets, targetSize: pixelSize, contentMode: .aspectFill, options: requestConfiguration)
    }

    /// 停止预热
    public func terminateResourceWarming(assets: [PHAsset], pixelSize: CGSize) {
        guard !assets.isEmpty else { return }
        let requestConfiguration = PHImageRequestOptions()
        requestConfiguration.deliveryMode = .highQualityFormat
        requestConfiguration.resizeMode = .fast
        requestConfiguration.isSynchronous = false
        requestConfiguration.isNetworkAccessAllowed = false
        cachingManager.stopCachingImages(for: assets, targetSize: pixelSize, contentMode: .aspectFill, options: requestConfiguration)
    }

    /// 可选：清空缓存（如内存警告时）
    public func flushMemoryStore() { PRThumbnailStorage.shared.clearAllCache() }
}
