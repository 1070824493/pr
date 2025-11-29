//
//  PRAssetThumbnailProvider.swift

//

//

//  统一缩略图加载入口（两段式：fastFormat → highQualityFormat），
//  支持像素缓存、预热与 iCloud 退避策略。
//  用法：在页面创建一个 provider 实例注入到 Cell；避免单例带来的强依赖。
//  -----------------------------------------------------------
//  依赖：PRAssetsHelper.fetchFastThumbnail / fetchHighQualityThumbnail
//

import SwiftUI
import Photos

// MARK: - 内存缓存（像素级，避免滚动闪动）
final class PRAssetImageCache {
    static let shared = PRAssetImageCache()
    let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 600
        cache.totalCostLimit = 160 * 1024 * 1024 // ~160MB，可按机型调
    }
    func generateCacheKey(for id: String, size: CGSize, mode: PHImageRequestOptionsDeliveryMode) -> NSString {
        NSString(string: "\(id)_\(Int(size.width))x\(Int(size.height))_\(mode.rawValue)")
    }
    func clearAllCache() { cache.removeAllObjects() }
}

// MARK: - 单张缩略图 Loader
/// 单张缩略图 Loader（两段式加载）
private final class PRAssetThumbLoader: ObservableObject {
    @Published var image: UIImage?
    private var task: Task<Void, Never>?

    /// 加载指定资产缩略图（优先显示缓存/快速图，随后替换为高清图）
    func startLoadingThumbnail(asset: PHAsset, targetSize: CGSize, preferFast: Bool) {
        let cache = PRAssetImageCache.shared
        let fastKey = cache.generateCacheKey(for: asset.localIdentifier, size: targetSize, mode: .fastFormat)
        let hqKey   = cache.generateCacheKey(for: asset.localIdentifier, size: targetSize, mode: .highQualityFormat)

        // 命中缓存先显示
        if let v = cache.cache.object(forKey: fastKey) { self.image = v }
        else if let v = cache.cache.object(forKey: hqKey) { self.image = v }

        task?.cancel()
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                // 先快图：不走网络，首帧快
                if preferFast || self.image == nil {
                    if !Task.isCancelled {
                        let fast = try await PRAssetsHelper.shared.fetchFastThumbnail(
                            for: asset,
                            targetSize: CGSize(width: targetSize.width * 2, height: targetSize.height * 2)
                        )
                        let cost = max(1, Int(targetSize.width * targetSize.height) * 4)
                        cache.cache.setObject(fast, forKey: fastKey, cost: cost)
                        await MainActor.run { if self.image == nil { self.image = fast } }
                    }
                }
                // 再高清：若需要 iCloud 下载则退避（PRAssetsHelper 内部已处理）
                if !Task.isCancelled {
                    let hq = try await PRAssetsHelper.shared.fetchHighQualityThumbnail(
                        for: asset,
                        targetSize: CGSize(width: targetSize.width * 2, height: targetSize.height * 2),
                        deliveryMode: .highQualityFormat
                    )
                    let cost = max(1, Int(targetSize.width * targetSize.height) * 4)
                    cache.cache.setObject(hq, forKey: hqKey, cost: cost)
                    await MainActor.run {
                        // 仅在更清晰时替换，降低抖动
                        if self.image?.size != hq.size { self.image = hq }
                    }
                }
            } catch {
                // 静默失败：保留已有图或占位
            }
        }
    }

    deinit { task?.cancel() }
}

// MARK: - SwiftUI 包装视图
/// SwiftUI 缩略图视图包装
private struct PRAssetThumbnailView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let placeholder: Image
    let preferFastFirst: Bool

    @StateObject private var loader = PRAssetThumbLoader()
    @State private var appeared = false

    var body: some View {
        ZStack {
            if let ui = loader.image {
                Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledToFill()
                .transition(.opacity.combined(with: .scale(scale: 0.995)))
            } else {
                placeholder.resizable().scaledToFill().opacity(0.35)
            }
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            loader.startLoadingThumbnail(asset: asset, targetSize: targetSize, preferFast: preferFastFirst)
        }
        .onChange(of: asset.localIdentifier) { _ in
            loader.startLoadingThumbnail(asset: asset, targetSize: targetSize, preferFast: preferFastFirst)
        }
        .clipped()
    }
}

// MARK: - 对外 Provider（可实例化；内部共享缓存）
/// 缩略图 Provider（带像素缓存与预热）
public final class PRAssetThumbnailProvider {

    private let preheater = PHCachingImageManager()

    public init() {}

    /// SwiftUI 友好的缩略图视图（带缓存 & 防闪动 & 退避策略）
    /// SwiftUI 友好的缩略图视图（带缓存 & 防闪动 & 退避策略）
    public func createThumbnailView(
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
    /// 批量预热（建议在列表滚动 onAppear 里对后续 12~24 张调用）
    public func startPreheatingAssets(assets: [PHAsset], pixelSize: CGSize) {
        guard !assets.isEmpty else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .fast
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = false // 预热不触发网络
        preheater.startCachingImages(for: assets, targetSize: pixelSize, contentMode: .aspectFill, options: opts)
    }

    /// 停止预热
    /// 停止预热
    public func stopPreheatingAssets(assets: [PHAsset], pixelSize: CGSize) {
        guard !assets.isEmpty else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .fast
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = false
        preheater.stopCachingImages(for: assets, targetSize: pixelSize, contentMode: .aspectFill, options: opts)
    }

    /// 可选：清空缓存（如内存警告时）
    /// 清空缓存（如内存警告时）
    public func purgeCache() { PRAssetImageCache.shared.clearAllCache() }
}
