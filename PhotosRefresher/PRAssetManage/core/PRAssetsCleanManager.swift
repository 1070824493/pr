//
//  PRPhotoMapManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import SwiftUI
import ImageIO

/// 照片分析统一入口与管线管理器
/// - 职责: 权限申请、资产拉取、分阶段并发分析、缓存持久化与首页 Dashboard 构建
/// - 线程: 管线触发在后台并发，状态/地图更新在 `@MainActor`
public class PRAssetsCleanManager: NSObject, ObservableObject {
    public static let shared = PRAssetsCleanManager()

    // MARK: - 状态与公开属性
    @Published public private(set) var state: PRAssetsPiplineStatus = .requesting
    @Published public private(set) var totalSize: Int64 = 0
    @Published public private(set) var allAssets: [PHAsset] = []

    // 单资产类目
    @Published public private(set) var assetsInfoForScreenShot = PRAssetsInfo(.PhotosScreenshot)
    @Published public private(set) var assetsInfoForLivePhoto = PRAssetsInfo(.PhotosLive)
    @Published public private(set) var assetsInfoForSelfiePhotos = PRAssetsInfo(.selfiephoto)
    @Published public private(set) var assetsInfoForBackPhotos = PRAssetsInfo(.backphoto)
    @Published public private(set) var assetsInfoForVideo = PRAssetsInfo(.VideoAll)
    // 分组/重型类目
    @Published public private(set) var assetsInfoForSimilar = PRAssetsInfo(.PhotosSimilar)
    @Published public private(set) var assetsInfoForBlurry = PRAssetsInfo(.PhotosBlurry)
    @Published public private(set) var assetsInfoForDuplicate = PRAssetsInfo(.PhotosDuplicate)
    @Published public private(set) var assetsInfoForTextPhotos = PRAssetsInfo(.PhotosText)
    @Published public private(set) var assetsInfoForLargeVideo = PRAssetsInfo(.VideoLarge)
    
    @Published public private(set) var snap: PRDashboardSnapshot?

    // 删除广播（外部写入触发即时扣减）
    @Published public var lastDeleteAssets: [PHAsset] = [] {
        didSet {
            let deletedItems = lastDeleteAssets
            guard !deletedItems.isEmpty else { return }
            Task { @MainActor in self.removeDeletedPhotoItems(deletedItems) }
        }
    }

    // 权限弹窗
    @Published public var permissionAlert: PRAlertModalModel?
    public var permissionAlertOnDismiss: (() -> Void)?

    // MARK: - 依赖/内部状态
    private var allPHAssets: PHFetchResult<PHAsset>?
    private let files: PRSaveAssetDir
    private let prChunkScheduler: PRSegmentScheduler
    private let assetCache = NSCache<NSString, PHAsset>()
    private var progress: PRSnapInProgress?
    private let VIDEO_LARGE_SIZE: Int64 = 100 * 1024 * 1024

    // MARK: - Init
    override private init() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("photos_refresher_photo_v3")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.files = PRSaveAssetDir(storageDirectory: directory)
        self.prChunkScheduler = PRSegmentScheduler(chunkSize: 500, files: files)
        super.init()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - 对外入口
    /// 重新加载全库并启动分析管线（含缓存秒显）
    public func refreshAssetRepositoryAndInitiateSequence() {
        solicitLibraryAuthorization { [weak self] authorized in
            guard let selfReference = self else { return }
            guard authorized else {
                selfReference.state = .permissionDefined
                return
            }
            PHPhotoLibrary.shared().register(selfReference)
            Task(priority: .userInitiated) {
                await selfReference.restoreFromCache() // 秒显缓存
            let allAssets = selfReference.fetchAllAssetsReverseOrder()
            await selfReference.prChunkScheduler.configureSnapshotParameters(with: allAssets)
            await selfReference.startOrContinueProcessing()
            }
        }
    }

    /// 申请相册读写权限，失败时弹出前往设置提示
    public func solicitLibraryAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] authorizationStatus in
            DispatchQueue.main.async {
                guard let selfReference = self else { return }
                if authorizationStatus == .authorized || authorizationStatus == .limited {
                    completion(true)
                } else {
                    selfReference.state = .permissionDefined
                    selfReference.presentAuthorizationGuidance(for: authorizationStatus)
                    completion(false)
                }
            }
        }
    }
    
    @MainActor private func extractRepresentativeIdentifiers(_ photoMap: PRAssetsInfo) -> [String] {
        let assetIds = photoMap.assets.prefix(2).map({$0.assetIdentifier})
        if !assetIds.isEmpty {
            return assetIds
        }
        
        let doubleAssetsIds = photoMap.groupAssets.prefix(2).compactMap({$0.first?.assetIdentifier})
        if !doubleAssetsIds.isEmpty {
            return doubleAssetsIds
        }
        
        let doubleAssetIDs = photoMap.groupAssetLocalIdentifiers.prefix(2).compactMap({$0.first})
        if !doubleAssetIDs.isEmpty {
            return doubleAssetIDs
        }
        
        return []
    }

    @MainActor private func composeDashboardSnapshot() -> PRDashboardSnapshot {
        let dashboardCells: [PRDashboardCell] = [
            PRDashboardCell(category: .PhotosScreenshot,   bytes: assetsInfoForScreenShot.bytes,   repID: extractRepresentativeIdentifiers(assetsInfoForScreenShot), count: assetsInfoForScreenShot.assets.count),
            PRDashboardCell(category: .PhotosLive,    bytes: assetsInfoForLivePhoto.bytes,         repID: extractRepresentativeIdentifiers(assetsInfoForLivePhoto), count: assetsInfoForLivePhoto.assets.count),
            PRDashboardCell(category: .selfiephoto,  bytes: assetsInfoForSelfiePhotos.bytes,       repID: extractRepresentativeIdentifiers(assetsInfoForSelfiePhotos), count: assetsInfoForSelfiePhotos.assets.count),
            PRDashboardCell(category: .backphoto,    bytes: assetsInfoForBackPhotos.bytes,         repID: extractRepresentativeIdentifiers(assetsInfoForBackPhotos), count: assetsInfoForBackPhotos.assets.count),
            PRDashboardCell(category: .VideoAll,     bytes: assetsInfoForVideo.bytes,          repID: extractRepresentativeIdentifiers(assetsInfoForVideo), count: assetsInfoForVideo.assets.count),
            PRDashboardCell(category: .VideoLarge,   bytes: assetsInfoForLargeVideo.bytes,        repID: extractRepresentativeIdentifiers(assetsInfoForLargeVideo), count: assetsInfoForLargeVideo.assets.count),
            PRDashboardCell(category: .PhotosBlurry,  bytes: assetsInfoForBlurry.bytes,       repID: extractRepresentativeIdentifiers(assetsInfoForBlurry), count: assetsInfoForBlurry.assets.count),
            PRDashboardCell(category: .PhotosText,    bytes: assetsInfoForTextPhotos.bytes,         repID: extractRepresentativeIdentifiers(assetsInfoForTextPhotos), count: assetsInfoForTextPhotos.assets.count),
            PRDashboardCell(category: .PhotosSimilar, bytes: assetsInfoForSimilar.bytes,      repID: extractRepresentativeIdentifiers(assetsInfoForSimilar), count: assetsInfoForSimilar.assets.count),
            PRDashboardCell(category: .PhotosDuplicate, bytes: assetsInfoForDuplicate.bytes,  repID: extractRepresentativeIdentifiers(assetsInfoForDuplicate), count: assetsInfoForDuplicate.assets.count)
        ]
        return PRDashboardSnapshot(cells: dashboardCells, totalSize: totalSize, updatedAt: Date())
    }

    @MainActor private func archiveDashboardSnapshot(_ snapshot: PRDashboardSnapshot) {
        if let encodedData = try? JSONEncoder().encode(snapshot) {
            try? encodedData.write(to: files.dashboard, options: .atomic)
        }
    }

    @MainActor private func retrievePersistedDashboardSnapshot() -> PRDashboardSnapshot? {
        if let fileData = try? Data(contentsOf: files.dashboard),
           let decodedSnapshot = try? JSONDecoder().decode(PRDashboardSnapshot.self, from: fileData) {
            return decodedSnapshot
        }
        return nil
    }

    private func updateDashboardMetrics() {
        Task { @MainActor in
            let dashboardSnapshot = composeDashboardSnapshot()
            snap = dashboardSnapshot
            archiveDashboardSnapshot(dashboardSnapshot)
        }
    }

    // MARK: - 秒显缓存
    private func restoreFromCache() async {
        await MainActor.run { self.state = .loading }

        // Dashboard 优先秒显
        if let cachedDashboard = await MainActor.run(body: { retrievePersistedDashboardSnapshot() }) {
            await MainActor.run { self.snap = cachedDashboard }
        }

        if let mapData = try? Data(contentsOf: files.maps),
           let photoMaps = try? JSONDecoder().decode(PRAssetsSnapInfo.self, from: mapData),
           photoMaps.bytesSchemaVersion == kDataFormatVersion {
            await MainActor.run {
                assetsInfoForScreenShot.assets = photoMaps.screenshot
                assetsInfoForScreenShot.bytes = photoMaps.screenshotBytes
                assetsInfoForLivePhoto.assets = photoMaps.live
                assetsInfoForLivePhoto.bytes = photoMaps.liveBytes
                assetsInfoForVideo.assets = photoMaps.allvideo
                assetsInfoForVideo.bytes = photoMaps.allvideoBytes
                assetsInfoForSelfiePhotos.assets = photoMaps.selfie
                assetsInfoForSelfiePhotos.bytes = photoMaps.selfieBytes
                assetsInfoForBackPhotos.assets = photoMaps.back
                assetsInfoForBackPhotos.bytes = photoMaps.backBytes
                assetsInfoForLargeVideo.assets = photoMaps.large
                assetsInfoForLargeVideo.bytes = photoMaps.largeBytes
                assetsInfoForBlurry.assets = photoMaps.blurry
                assetsInfoForBlurry.bytes = photoMaps.blurryBytes
                assetsInfoForTextPhotos.assets = photoMaps.text
                assetsInfoForTextPhotos.bytes = photoMaps.textBytes
                assetsInfoForSimilar.groupAssetLocalIdentifiers = photoMaps.similarGroupIds
                assetsInfoForSimilar.groupAssets = photoMaps.similarGroupModels
                assetsInfoForSimilar.bytes = photoMaps.similarBytes
                assetsInfoForDuplicate.groupAssetLocalIdentifiers = photoMaps.duplicateGroupIds
                assetsInfoForDuplicate.groupAssets = photoMaps.duplicateGroupModels
                assetsInfoForDuplicate.bytes = photoMaps.duplicateBytes
                recalculateTotalStorage()
            }
        }

        if let progressData = try? Data(contentsOf: files.progress),
           let progressSnapshot = try? JSONDecoder().decode(PRSnapInProgress.self, from: progressData),
           progressSnapshot.dataFormatVersion == kDataFormatVersion {
            self.progress = progressSnapshot
        } else {
            self.progress = nil
        }
    }

    // MARK: - 重算 totalSize 时同步更新 Dashboard
    private func recalculateTotalStorage() {
        let calculatedSize = assetsInfoForScreenShot.bytes + assetsInfoForLivePhoto.bytes + assetsInfoForVideo.bytes + assetsInfoForSelfiePhotos.bytes + assetsInfoForBackPhotos.bytes +
                assetsInfoForSimilar.bytes + assetsInfoForBlurry.bytes + assetsInfoForDuplicate.bytes +
                assetsInfoForTextPhotos.bytes + assetsInfoForLargeVideo.bytes
        if calculatedSize != totalSize { totalSize = calculatedSize }
        updateDashboardMetrics()
    }

    // MARK: - 拉全库（倒序）
    private func fetchAllAssetsReverseOrder() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        allPHAssets = fetchResult
        var assetArray: [PHAsset] = []
        assetArray.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { assetItem,_,_ in assetArray.append(assetItem) }
        allAssets = assetArray
        return assetArray
    }

    // MARK: - 主流程：Phase A → B1 并发 → B2 并发 → idle
    private func startOrContinueProcessing() async {
        await MainActor.run { self.state = .loading }

        let segmentCount = await prChunkScheduler.calculateSegmentQuantity()
        guard segmentCount > 0 else {
            await MainActor.run { self.state = .idle }
            return
        }

        // Phase A：轻量（串行；每块回调 + 节流持久化）
        await executeBasicAssetAnalysis(totalSegments: segmentCount)

        // Phase B1：相似/重复/大视频（并发；每块回调 + 节流持久化）
        await withTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask { await self.performSimilarityGrouping(totalSegments: segmentCount) }
            taskGroup.addTask { await self.performDuplicateDetection(totalSegments: segmentCount) }
            taskGroup.addTask { await self.performLargeVideoScanning(totalSegments: segmentCount) }
            await taskGroup.waitForAll()
        }

        // Phase B2：模糊/文字（并发；每块回调 + 节流持久化）
        await withTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask { await self.performBlurDetection(totalSegments: segmentCount) }
            taskGroup.addTask { await self.performTextDetection(totalSegments: segmentCount) }
            await taskGroup.waitForAll()
        }

        await MainActor.run {
            self.saveCurrentStateToDisk(forceWrite: true)
            self.state = .idle
        }
    }

    // MARK: - Phase A：轻量三类
    private func executeBasicAssetAnalysis(totalSegments: Int) async {
        let startingIndex = (progress?.lastPrimaryPhase ?? -1) + 1
        guard startingIndex < totalSegments else { return }
        var saveCounter = 0

        for segmentIndex in startingIndex..<totalSegments {
            guard let segmentData = await prChunkScheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }

            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let screenshots = segmentAssets.filter { $0.mediaType == .image && $0.mediaSubtypes.contains(.photoScreenshot) }
            let livePhotos = segmentAssets.filter { $0.mediaSubtypes.contains(.photoLive) }
            let videos = segmentAssets.filter { $0.mediaType == .video }
            let images = segmentAssets.filter { $0.mediaType == .image }

            @inline(__always)
            func createAssetModels(_ assetArray: [PHAsset]) -> [PRAssetsAnalyzeResult] {
                assetArray.map {
                    let entry = assetEntryMap[$0.localIdentifier]
                    return PRAssetsAnalyzeResult(id: $0.localIdentifier, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
                }
            }

            let cameraSplitResult = await self.categorizePhotosByCameraType(in: images)
            let selfieModels: [PRAssetsAnalyzeResult] = cameraSplitResult.frontCamera.map {
                let entry = assetEntryMap[$0]
                return PRAssetsAnalyzeResult(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }
            let backModels: [PRAssetsAnalyzeResult] = cameraSplitResult.rearCamera.map {
                let entry = assetEntryMap[$0]
                return PRAssetsAnalyzeResult(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.PhotosScreenshot, newModels: createAssetModels(screenshots))
                self.mergeSingleCategoryAssets(.PhotosLive, newModels: createAssetModels(livePhotos))
                self.mergeSingleCategoryAssets(.VideoAll, newModels: createAssetModels(videos))
                self.mergeSingleCategoryAssets(.selfiephoto, newModels: selfieModels)
                self.mergeSingleCategoryAssets(.backphoto, newModels: backModels)
                self.recalculateTotalStorage()
            }

            progress = ensureProgressSnapshot()
            progress?.lastPrimaryPhase = segmentIndex
            saveCounter += 1
            if saveCounter >= kSaveInterval {
                saveCounter = 0
                await MainActor.run { self.saveCurrentStateToDisk() }
            }
        }

        await MainActor.run { self.saveCurrentStateToDisk() }
    }

    // MARK: - Phase B1：相似
    private func performSimilarityGrouping(totalSegments: Int) async {
        let startingIndex = (progress?.lastSimilarityPhase ?? -1) + 1
        guard startingIndex < totalSegments else { return }
        var saveCounter = 0

        for segmentIndex in startingIndex..<totalSegments {
            guard let segmentData = await prChunkScheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let similarityClusters = await PRSimilarAnalyzer.locateAnalogousAssetClusters(in: segmentAssets)

            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let clusterModels: [[PRAssetsAnalyzeResult]] = similarityClusters.compactMap { clusterIdentifiers in
                let modelArray = clusterIdentifiers.map { identifier -> PRAssetsAnalyzeResult in
                    let entry = assetEntryMap[identifier]
                    return PRAssetsAnalyzeResult(id: identifier, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
                }
                return modelArray.count >= 2 ? modelArray : nil
            }

            await MainActor.run {
                self.mergeGroupedAssets(.PhotosSimilar, newGroupIDs: similarityClusters, newGroupModels: clusterModels)
                self.recalculateTotalStorage()
            }

            progress = ensureProgressSnapshot()
            progress?.lastSimilarityPhase = segmentIndex
            saveCounter += 1
            if saveCounter >= kSaveInterval {
                saveCounter = 0
                await MainActor.run { self.saveCurrentStateToDisk() }
            }
        }

        await MainActor.run { self.saveCurrentStateToDisk() }
    }

    // MARK: - Phase B1：重复
    private func performDuplicateDetection(totalSegments: Int) async {
        let startingIndex = (progress?.lastDuplicationPhase ?? -1) + 1
        guard startingIndex < totalSegments else { return }
        var saveCounter = 0

        for segmentIndex in startingIndex..<totalSegments {
            guard let segmentData = await prChunkScheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let duplicateClusters = await PRDuplicateAnalyzer.isolateRedundantClusters(in: segmentAssets)

            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let clusterModels: [[PRAssetsAnalyzeResult]] = duplicateClusters.compactMap { clusterIdentifiers in
                let modelArray = clusterIdentifiers.map { identifier -> PRAssetsAnalyzeResult in
                    let entry = assetEntryMap[identifier]
                    return PRAssetsAnalyzeResult(id: identifier, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
                }
                return modelArray.count >= 2 ? modelArray : nil
            }

            await MainActor.run {
                self.mergeGroupedAssets(.PhotosDuplicate, newGroupIDs: duplicateClusters, newGroupModels: clusterModels)
                self.recalculateTotalStorage()
            }

            progress = ensureProgressSnapshot()
            progress?.lastDuplicationPhase = segmentIndex
            saveCounter += 1
            if saveCounter >= kSaveInterval {
                saveCounter = 0
                await MainActor.run { self.saveCurrentStateToDisk() }
            }
        }

        await MainActor.run { self.saveCurrentStateToDisk() }
    }

    // MARK: - Phase B1：大视频
    private func performLargeVideoScanning(totalSegments: Int) async {
        let startingIndex = (progress?.lastOversizedPhase ?? -1) + 1
        guard startingIndex < totalSegments else { return }
        var saveCounter = 0

        for segmentIndex in startingIndex..<totalSegments {
            guard let segmentData = await prChunkScheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let largeVideoIDs = await PRLargeVideoAnalyzer.detectVoluminousVideoEntities(in: segmentAssets, thresholdBytes: VIDEO_LARGE_SIZE)
            let largeVideoModels: [PRAssetsAnalyzeResult] = largeVideoIDs.map {
                let entry = assetEntryMap[$0]
                return PRAssetsAnalyzeResult(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.VideoLarge, newModels: largeVideoModels)
                self.recalculateTotalStorage()
            }

            progress = ensureProgressSnapshot()
            progress?.lastOversizedPhase = segmentIndex
            saveCounter += 1
            if saveCounter >= kSaveInterval {
                saveCounter = 0
                await MainActor.run { self.saveCurrentStateToDisk() }
            }
        }

        await MainActor.run { self.saveCurrentStateToDisk() }
    }

    // MARK: - Phase B2：模糊
    private func performBlurDetection(totalSegments: Int) async {
        let startingIndex = (progress?.lastBlurDetectionPhase ?? -1) + 1
        guard startingIndex < totalSegments else { return }
        var saveCounter = 0

        for segmentIndex in startingIndex..<totalSegments {
            guard let segmentData = await prChunkScheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let blurryImageIDs = await PRBlurryAnalyzer.scanForLowResolutionEntities(in: segmentAssets)
            let blurryModels: [PRAssetsAnalyzeResult] = blurryImageIDs.map {
                let entry = assetEntryMap[$0]
                return PRAssetsAnalyzeResult(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.PhotosBlurry, newModels: blurryModels)
                self.recalculateTotalStorage()
            }

            progress = ensureProgressSnapshot()
            progress?.lastBlurDetectionPhase = segmentIndex
            saveCounter += 1
            if saveCounter >= kSaveInterval {
                saveCounter = 0
                await MainActor.run { self.saveCurrentStateToDisk() }
            }
        }

        await MainActor.run { self.saveCurrentStateToDisk() }
    }

    // MARK: - Phase B2：文字
    private func performTextDetection(totalSegments: Int) async {
        let startingIndex = (progress?.lastTextDetectionPhase ?? -1) + 1
        guard startingIndex < totalSegments else { return }
        var saveCounter = 0

        for segmentIndex in startingIndex..<totalSegments {
            guard let segmentData = await prChunkScheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let textImageIDs = await PRTextAnalyzer.detectGlyphBearingEntities(in: segmentAssets)
            let textModels: [PRAssetsAnalyzeResult] = textImageIDs.map {
                let entry = assetEntryMap[$0]
                return PRAssetsAnalyzeResult(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.PhotosText, newModels: textModels)
                self.recalculateTotalStorage()
            }

            progress = ensureProgressSnapshot()
            progress?.lastTextDetectionPhase = segmentIndex
            saveCounter += 1
            if saveCounter >= kSaveInterval {
                saveCounter = 0
                await MainActor.run { self.saveCurrentStateToDisk() }
            }
        }

        await MainActor.run { self.saveCurrentStateToDisk() }
    }

    // MARK: - 合并 & 统计（主线程）
    @MainActor
    private func mergeSingleCategoryAssets(_ category: PRAssetType, newModels: [PRAssetsAnalyzeResult]) {
        guard !newModels.isEmpty else { return }

        func addUniqueModels(_ incomingModels: [PRAssetsAnalyzeResult], to existingArray: inout [PRAssetsAnalyzeResult]) -> Int64 {
            var existingIDs = Set(existingArray.map(\.assetIdentifier))
            var sizeIncrease: Int64 = 0
            for model in incomingModels where existingIDs.insert(model.assetIdentifier).inserted {
                existingArray.append(model)
                sizeIncrease &+= model.storageSize
            }
            return sizeIncrease
        }

        switch category {
        case .PhotosScreenshot:
            assetsInfoForScreenShot.bytes &+= addUniqueModels(newModels, to: &assetsInfoForScreenShot.assets)
        case .PhotosLive:
            assetsInfoForLivePhoto.bytes &+= addUniqueModels(newModels, to: &assetsInfoForLivePhoto.assets)
        case .VideoAll:
            assetsInfoForVideo.bytes &+= addUniqueModels(newModels, to: &assetsInfoForVideo.assets)
        case .selfiephoto:
            assetsInfoForSelfiePhotos.bytes &+= addUniqueModels(newModels, to: &assetsInfoForSelfiePhotos.assets)
        case .backphoto:
            assetsInfoForBackPhotos.bytes &+= addUniqueModels(newModels, to: &assetsInfoForBackPhotos.assets)
        case .PhotosBlurry:
            assetsInfoForBlurry.bytes &+= addUniqueModels(newModels, to: &assetsInfoForBlurry.assets)
        case .PhotosText:
            assetsInfoForTextPhotos.bytes &+= addUniqueModels(newModels, to: &assetsInfoForTextPhotos.assets)
        case .VideoLarge:
            assetsInfoForLargeVideo.bytes &+= addUniqueModels(newModels, to: &assetsInfoForLargeVideo.assets)
        default: break
        }
    }

    @MainActor
    private func mergeGroupedAssets(
        _ category: PRAssetType,
        newGroupIDs: [[String]],
        newGroupModels: [[PRAssetsAnalyzeResult]]
    ) {
        guard category == .PhotosSimilar || category == .PhotosDuplicate else { return }
        guard !newGroupIDs.isEmpty else { return }

        if category == .PhotosSimilar {
            assetsInfoForSimilar.groupAssetLocalIdentifiers = PRGroupMerge.mergeAssetGroups(existingGroups: assetsInfoForSimilar.groupAssetLocalIdentifiers, newGroups: newGroupIDs)
        } else {
            assetsInfoForDuplicate.groupAssetLocalIdentifiers = PRGroupMerge.mergeAssetGroups(existingGroups: assetsInfoForDuplicate.groupAssetLocalIdentifiers, newGroups: newGroupIDs)
        }

        func buildModelLookup(existingGroups: [[PRAssetsAnalyzeResult]], newGroups: [[PRAssetsAnalyzeResult]]) -> [String: PRAssetsAnalyzeResult] {
            var modelLookup: [String: PRAssetsAnalyzeResult] = [:]
            modelLookup.reserveCapacity(existingGroups.reduce(0){$0+$1.count} + newGroups.reduce(0){$0+$1.count})
            for model in existingGroups.flatMap({$0}) where modelLookup[model.assetIdentifier] == nil {
                modelLookup[model.assetIdentifier] = model
            }
            for model in newGroups.flatMap({$0}) where modelLookup[model.assetIdentifier] == nil {
                modelLookup[model.assetIdentifier] = model
            }
            return modelLookup
        }

        func rebuildGroupsAndCalculateSizeChange(map: inout PRAssetsInfo, additionalModels: [[PRAssetsAnalyzeResult]]) -> Int64 {
            let previousIDs = Set(map.groupAssets.flatMap { $0.map(\.assetIdentifier) })
            let modelLookup = buildModelLookup(existingGroups: map.groupAssets, newGroups: additionalModels)

            let updatedGroups: [[PRAssetsAnalyzeResult]] = map.groupAssetLocalIdentifiers.compactMap { idArray in
                let models = idArray.compactMap { modelLookup[$0] }.sorted(by: {$0.storageSize > $1.storageSize})
                return models.count >= 2 ? models : nil
            }
            map.groupAssets = updatedGroups

            let currentIDs = Set(updatedGroups.flatMap { $0.map(\.assetIdentifier) })
            let addedIDs = currentIDs.subtracting(previousIDs)
            let sizeLookup = Dictionary(uniqueKeysWithValues: modelLookup.map { ($0.key, $0.value.storageSize) })
            return addedIDs.reduce(Int64(0)) { $0 &+ (sizeLookup[$1] ?? 0) }
        }

        if category == .PhotosSimilar {
            let sizeDelta = rebuildGroupsAndCalculateSizeChange(map: &assetsInfoForSimilar, additionalModels: newGroupModels)
            assetsInfoForSimilar.bytes &+= sizeDelta
        } else {
            let sizeDelta = rebuildGroupsAndCalculateSizeChange(map: &assetsInfoForDuplicate, additionalModels: newGroupModels)
            assetsInfoForDuplicate.bytes &+= sizeDelta
        }

        recalculateTotalStorage()
    }

    // MARK: - 持久化
    @MainActor
    private func saveCurrentStateToDisk(forceWrite: Bool = false) {
        let mapSnapshot = PRAssetsSnapInfo(
            screenshot: assetsInfoForScreenShot.assets,
            screenshotBytes: assetsInfoForScreenShot.bytes,
            live: assetsInfoForLivePhoto.assets,
            liveBytes: assetsInfoForLivePhoto.bytes,
            allvideo: assetsInfoForVideo.assets,
            allvideoBytes: assetsInfoForVideo.bytes,
            selfie: assetsInfoForSelfiePhotos.assets,
            selfieBytes: assetsInfoForSelfiePhotos.bytes,
            back: assetsInfoForBackPhotos.assets,
            backBytes: assetsInfoForBackPhotos.bytes,
            large: assetsInfoForLargeVideo.assets,
            largeBytes: assetsInfoForLargeVideo.bytes,
            blurry: assetsInfoForBlurry.assets,
            blurryBytes: assetsInfoForBlurry.bytes,
            text: assetsInfoForTextPhotos.assets,
            textBytes: assetsInfoForTextPhotos.bytes,
            similarGroupIds: assetsInfoForSimilar.groupAssetLocalIdentifiers,
            similarGroupModels: assetsInfoForSimilar.groupAssets,
            similarBytes: assetsInfoForSimilar.bytes,
            duplicateGroupIds: assetsInfoForDuplicate.groupAssetLocalIdentifiers,
            duplicateGroupModels: assetsInfoForDuplicate.groupAssets,
            duplicateBytes: assetsInfoForDuplicate.bytes,
            totalSize: totalSize,
            bytesSchemaVersion: kDataFormatVersion,
            updatedAt: Date()
        )
        if let encodedData = try? JSONEncoder().encode(mapSnapshot) {
            try? encodedData.write(to: files.maps, options: .atomic)
        }

        var currentProgress = ensureProgressSnapshot()
        if forceWrite {
            currentProgress.analysisTimestamp = Date()
            progress = currentProgress
        } else {
            progress?.analysisTimestamp = Date()
            currentProgress = progress ?? currentProgress
        }
        if let progressData = try? JSONEncoder().encode(currentProgress) {
            try? progressData.write(to: files.progress, options: .atomic)
        }
    }

    private func ensureProgressSnapshot() -> PRSnapInProgress {
        if let existingProgress = progress { return existingProgress }
        let newProgress = PRSnapInProgress(
            analysisIdentifier: "hash-\(UUID().uuidString)",
            lastPrimaryPhase: -1,
            lastSimilarityPhase: -1,
            lastDuplicationPhase: -1,
            lastOversizedPhase: -1,
            lastBlurDetectionPhase: -1,
            lastTextDetectionPhase: -1,
            dataFormatVersion: kDataFormatVersion,
            analysisTimestamp: Date()
        )
        progress = newProgress
        return newProgress
    }

    // MARK: - 删除应用（精确字节扣减）
    /// 将外部删除的资产应用到各类目地图中（精确字节扣减）
    public func removeDeletedPhotoItems(_ removed: [PHAsset]) {
        let removedIDs = Set(removed.map { $0.localIdentifier })
        guard !removedIDs.isEmpty else { return }

        Task { @MainActor in
            withTransaction(Transaction(animation: nil)) {
                func removeFromArray(_ array: inout [PRAssetsAnalyzeResult]) -> Int64 {
                    var removedSize: Int64 = 0
                    array.removeAll { model in
                        if removedIDs.contains(model.assetIdentifier) {
                            removedSize &+= model.storageSize
                            return true
                        }
                        return false
                    }
                    return removedSize
                }

                assetsInfoForScreenShot.bytes &-= removeFromArray(&assetsInfoForScreenShot.assets)
                assetsInfoForLivePhoto.bytes &-= removeFromArray(&assetsInfoForLivePhoto.assets)
                assetsInfoForVideo.bytes &-= removeFromArray(&assetsInfoForVideo.assets)
                assetsInfoForSelfiePhotos.bytes &-= removeFromArray(&assetsInfoForSelfiePhotos.assets)
                assetsInfoForBackPhotos.bytes &-= removeFromArray(&assetsInfoForBackPhotos.assets)
                assetsInfoForLargeVideo.bytes &-= removeFromArray(&assetsInfoForLargeVideo.assets)
                assetsInfoForBlurry.bytes &-= removeFromArray(&assetsInfoForBlurry.assets)
                assetsInfoForTextPhotos.bytes &-= removeFromArray(&assetsInfoForTextPhotos.assets)
                
                let duplicateRemovedSize = filterAssetsFromGroupedMap(&assetsInfoForDuplicate, removing: removedIDs)
                assetsInfoForDuplicate.bytes &-= duplicateRemovedSize
                let similarRemovedSize = filterAssetsFromGroupedMap(&assetsInfoForSimilar, removing: removedIDs)
                assetsInfoForSimilar.bytes &-= similarRemovedSize

                recalculateTotalStorage()
                self.saveCurrentStateToDisk()
            }
        }
    }

    @MainActor
    private func filterAssetsFromGroupedMap(_ map: inout PRAssetsInfo, removing identifiers: Set<String>) -> Int64 {
        var removedSize: Int64 = 0
        for group in map.groupAssets {
            for model in group where identifiers.contains(model.assetIdentifier) {
                removedSize &+= model.storageSize
            }
        }
        for i in map.groupAssets.indices {
            map.groupAssets[i].removeAll { identifiers.contains($0.assetIdentifier) }
        }
        map.groupAssets.removeAll { $0.count < 2 }
        for i in map.groupAssetLocalIdentifiers.indices {
            map.groupAssetLocalIdentifiers[i].removeAll { identifiers.contains($0) }
        }
        map.groupAssetLocalIdentifiers.removeAll { $0.count < 2 }
        return removedSize
    }

    // MARK: - 运行期：解析 PHAsset
    /// 解析并缓存单个 `PHAsset`（存在即取缓存，未命中则查询）
    public func resolveAssetEntity(for identifier: String) -> PHAsset? {
        if let cachedAsset = assetCache.object(forKey: identifier as NSString) { return cachedAsset }
        let assetArray = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).toArray()
        if let asset = assetArray.first {
            assetCache.setObject(asset, forKey: identifier as NSString)
            return asset
        }
        return nil
    }
}

// MARK: - PHPhotoLibraryChangeObserver（增量处理）
extension PRAssetsCleanManager: PHPhotoLibraryChangeObserver {

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let baseFetch = allPHAssets,
              let changeDetails = changeInstance.changeDetails(for: baseFetch) else { return }

        guard changeDetails.hasIncrementalChanges else {
            Task { self.refreshAssetRepositoryAndInitiateSequence() }
            return
        }

        let afterFetch = changeDetails.fetchResultAfterChanges
        self.allPHAssets = afterFetch
        let afterArray = afterFetch.toArray()

        var insertedAssets: [PHAsset] = []
        var removedAssets: [PHAsset] = []
        var changedAssets: [PHAsset] = []

        if let insertedIndexes = changeDetails.insertedIndexes { insertedAssets = insertedIndexes.map { afterFetch.object(at: $0) } }
        if let removedIndexes = changeDetails.removedIndexes { removedAssets = removedIndexes.map { baseFetch.object(at: $0) } }
        if let changedIndexes = changeDetails.changedIndexes { changedAssets = changedIndexes.map { afterFetch.object(at: $0) } }

        Task { @MainActor in self.state = .loading }

        if !removedAssets.isEmpty {
            self.removeDeletedPhotoItems(removedAssets)
            return
        }

        Task.detached(priority: .utility) { [weak self] in
            guard let selfReference = self else { return }
            await selfReference.rebuildDynamicMappings(afterArray)
            await MainActor.run {
                selfReference.saveCurrentStateToDisk()
                selfReference.state = .idle
            }
        }
    }

    private func rebuildDynamicMappings(_ allAssets: [PHAsset]) async {
        @inline(__always)
        func createAssetModel(_ asset: PHAsset) -> PRAssetsAnalyzeResult {
            let bytes = computeResourceVolume(asset)
            let date = Int64((asset.creationDate ?? .distantPast).timeIntervalSince1970)
            return PRAssetsAnalyzeResult(id: asset.localIdentifier, bytes: bytes, date: date, asset: asset)
        }

        let screenshots = allAssets.filter { $0.mediaType == .image && $0.mediaSubtypes.contains(.photoScreenshot) }.map(createAssetModel)
        let livePhotos = allAssets.filter { $0.mediaSubtypes.contains(.photoLive) }.map(createAssetModel)
        let videos = allAssets.filter { $0.mediaType == .video }.map(createAssetModel)

        await MainActor.run {
            withTransaction(Transaction(animation: nil)) {
                assetsInfoForScreenShot.assets = screenshots
                assetsInfoForScreenShot.bytes = screenshots.reduce(0) { $0 &+ $1.storageSize }

                assetsInfoForLivePhoto.assets = livePhotos
                assetsInfoForLivePhoto.bytes = livePhotos.reduce(0) { $0 &+ $1.storageSize }

                assetsInfoForVideo.assets = videos
                assetsInfoForVideo.bytes = videos.reduce(0) { $0 &+ $1.storageSize }
            }
            recalculateTotalStorage()
        }
    }
}

extension PRAssetsCleanManager {
    private enum CameraPosition { case front, rear }
    private func determineCameraFacing(for asset: PHAsset) async -> CameraPosition? {
        guard asset.mediaType == .image else { return nil }
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.version = .current
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
                guard let imageData = data else { continuation.resume(returning: nil); return }
                guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil), CGImageSourceGetCount(imageSource) > 0 else { continuation.resume(returning: nil); return }
                guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else { continuation.resume(returning: nil); return }
                var cameraPosition: CameraPosition?
                if let exifData = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                    if let lensModel = exifData[kCGImagePropertyExifLensModel] as? String {
                        let lens = lensModel.lowercased()
                        if lens.contains("front") { cameraPosition = .front }
                        else if lens.contains("back") || lens.contains("rear") { cameraPosition = .rear }
                    }
                }
                if cameraPosition == nil, let makerData = properties[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any] {
                    if let cameraType = makerData["CameraType" as CFString] as? String {
                        let camera = cameraType.lowercased()
                        if camera.contains("front") { cameraPosition = .front }
                        else if camera.contains("back") || camera.contains("rear") { cameraPosition = .rear }
                    }
                }
                continuation.resume(returning: cameraPosition)
            }
        }
    }

    private func categorizePhotosByCameraType(in assets: [PHAsset]) async -> (frontCamera: [String], rearCamera: [String]) {
        var frontIDs: [String] = []
        var rearIDs: [String] = []
        await withTaskGroup(of: (String, CameraPosition?).self) { taskGroup in
            for asset in assets { taskGroup.addTask { (asset.localIdentifier, await self.determineCameraFacing(for: asset)) } }
            for await (identifier, position) in taskGroup {
                if let cameraPosition = position {
                    if cameraPosition == .front { frontIDs.append(identifier) } else { rearIDs.append(identifier) }
                }
            }
        }
        return (frontIDs, rearIDs)
    }
}

// MARK: - 权限弹框
extension PRAssetsCleanManager {
    /// 权限受限提示弹窗（引导前往设置）
    func presentAuthorizationGuidance(for status: PHAuthorizationStatus) {
        let (title, message): (String, String) = {
            switch status {
            case .denied:
                return ("Unlock Full PR",
                        "We need access to your photos to detect duplicates, large files, and blurry shots. Enable photo access in Settings and start freeing up space now!")
            case .restricted:
                return ("Photo Access Restricted",
                        "Photo access is blocked by system or parental controls. Without it, we can't analyze your library or help you reclaim storage space.")
            case .limited:
                return ("Get Maximum Space Savings",
                        "Currently only a few photos are accessible. Grant access to your entire library in Settings to clean up faster and reclaim the most storage.")
            default:
                return ("Photo Access Needed",
                        "Enable photo access in Settings to scan your library, remove clutter, and instantly free up valuable space.")
            }
        }()
        
        permissionAlert = PRAlertModalModel(
            imgName: "", title: title, desc: message,
            firstBtnTitle: "Not Now", secondBtnTitle: "Open Settings",
            actionHandler: { [weak self] action in
                switch action {
                case .first:
                    self?.permissionAlert?.onDismiss?(); self?.permissionAlert = nil
                case .second:
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(settingsURL) }
                    self?.permissionAlert?.onDismiss?(); self?.permissionAlert = nil
                }
            },
            onDismiss: { [weak self] in
                self?.permissionAlertOnDismiss?()
                self?.permissionAlertOnDismiss = nil
                self?.permissionAlert = nil
            }
        )
    }
}
