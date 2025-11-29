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
public final class PRPhotoMapManager: NSObject, ObservableObject {
    public static let shared = PRPhotoMapManager()

    // MARK: - 状态与公开属性
    @Published public private(set) var state: PRPhotoPipelineState = .requesting
    @Published public private(set) var totalSize: Int64 = 0
    @Published public private(set) var allAssets: [PHAsset] = []

    // 单资产类目
    @Published public private(set) var screenshotPhotosMap = PRPhotoAssetsMap(.screenshot)
    @Published public private(set) var livePhotosMap = PRPhotoAssetsMap(.livePhoto)
    @Published public private(set) var selfiePhotosMap = PRPhotoAssetsMap(.selfiephoto)
    @Published public private(set) var backPhotosMap = PRPhotoAssetsMap(.backphoto)
    @Published public private(set) var allVideosMap = PRPhotoAssetsMap(.allvideo)
    // 分组/重型类目
    @Published public private(set) var similarPhotosMap = PRPhotoAssetsMap(.similarphoto)
    @Published public private(set) var blurryPhotosMap = PRPhotoAssetsMap(.blurryphoto)
    @Published public private(set) var duplicatePhotosMap = PRPhotoAssetsMap(.duplicatephoto)
    @Published public private(set) var textPhotosMap = PRPhotoAssetsMap(.textphoto)
    @Published public private(set) var largeVideosMap = PRPhotoAssetsMap(.largevideo)
    @Published public private(set) var similarVideosMap = PRPhotoAssetsMap(.similarvideo) // 预留
    
    @Published public private(set) var dashboard: PRDashboardSnapshot?

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
    private var fetchAll: PHFetchResult<PHAsset>?
    private let files: PRCacheFiles
    private let scheduler: PRChunkScheduler
    private let assetCache = NSCache<NSString, PHAsset>()
    private var progress: PRProgressSnapshot?
    private let largeVideoThreshold: Int64 = 100 * 1024 * 1024

    // MARK: - Init
    override private init() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ck_photo_v3")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.files = PRCacheFiles(storageDirectory: directory)
        self.scheduler = PRChunkScheduler(chunkSize: 500, files: files)
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
                selfReference.state = .noPermission
                return
            }
            PHPhotoLibrary.shared().register(selfReference)
            Task(priority: .userInitiated) {
                await selfReference.restoreFromCache() // 秒显缓存
            let allAssets = selfReference.fetchAllAssetsReverseOrder()
            await selfReference.scheduler.configureSnapshotParameters(with: allAssets)
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
                    selfReference.state = .noPermission
                    selfReference.presentAuthorizationGuidance(for: authorizationStatus)
                    completion(false)
                }
            }
        }
    }
    
    @MainActor private func extractRepresentativeIdentifiers(_ photoMap: PRPhotoAssetsMap) -> [String] {
        let assetIds = photoMap.assets.prefix(2).map({$0.assetIdentifier})
        if !assetIds.isEmpty {
            return assetIds
        }
        
        let doubleAssetsIds = photoMap.doubleAssets.prefix(2).compactMap({$0.first?.assetIdentifier})
        if !doubleAssetsIds.isEmpty {
            return doubleAssetsIds
        }
        
        let doubleAssetIDs = photoMap.doubleAssetIDs.prefix(2).compactMap({$0.first})
        if !doubleAssetIDs.isEmpty {
            return doubleAssetIDs
        }
        
        return []
    }

    @MainActor private func composeDashboardSnapshot() -> PRDashboardSnapshot {
        let dashboardCells: [PRDashboardCell] = [
            PRDashboardCell(category: .screenshot,   bytes: screenshotPhotosMap.totalBytes,   repID: extractRepresentativeIdentifiers(screenshotPhotosMap), count: screenshotPhotosMap.assets.count),
            PRDashboardCell(category: .livePhoto,    bytes: livePhotosMap.totalBytes,         repID: extractRepresentativeIdentifiers(livePhotosMap), count: livePhotosMap.assets.count),
            PRDashboardCell(category: .selfiephoto,  bytes: selfiePhotosMap.totalBytes,       repID: extractRepresentativeIdentifiers(selfiePhotosMap), count: selfiePhotosMap.assets.count),
            PRDashboardCell(category: .backphoto,    bytes: backPhotosMap.totalBytes,         repID: extractRepresentativeIdentifiers(backPhotosMap), count: backPhotosMap.assets.count),
            PRDashboardCell(category: .allvideo,     bytes: allVideosMap.totalBytes,          repID: extractRepresentativeIdentifiers(allVideosMap), count: allVideosMap.assets.count),
            PRDashboardCell(category: .largevideo,   bytes: largeVideosMap.totalBytes,        repID: extractRepresentativeIdentifiers(largeVideosMap), count: largeVideosMap.assets.count),
            PRDashboardCell(category: .blurryphoto,  bytes: blurryPhotosMap.totalBytes,       repID: extractRepresentativeIdentifiers(blurryPhotosMap), count: blurryPhotosMap.assets.count),
            PRDashboardCell(category: .textphoto,    bytes: textPhotosMap.totalBytes,         repID: extractRepresentativeIdentifiers(textPhotosMap), count: textPhotosMap.assets.count),
            PRDashboardCell(category: .similarphoto, bytes: similarPhotosMap.totalBytes,      repID: extractRepresentativeIdentifiers(similarPhotosMap), count: similarPhotosMap.assets.count),
            PRDashboardCell(category: .duplicatephoto, bytes: duplicatePhotosMap.totalBytes,  repID: extractRepresentativeIdentifiers(duplicatePhotosMap), count: duplicatePhotosMap.assets.count)
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
            dashboard = dashboardSnapshot
            archiveDashboardSnapshot(dashboardSnapshot)
        }
    }

    // MARK: - 秒显缓存
    private func restoreFromCache() async {
        await MainActor.run { self.state = .loading }

        // Dashboard 优先秒显
        if let cachedDashboard = await MainActor.run(body: { retrievePersistedDashboardSnapshot() }) {
            await MainActor.run { self.dashboard = cachedDashboard }
        }

        if let mapData = try? Data(contentsOf: files.maps),
           let photoMaps = try? JSONDecoder().decode(PRMapsSnapshot.self, from: mapData),
           photoMaps.bytesSchemaVersion == kDataFormatVersion {
            await MainActor.run {
                screenshotPhotosMap.assets = photoMaps.screenshot
                screenshotPhotosMap.totalBytes = photoMaps.screenshotBytes
                livePhotosMap.assets = photoMaps.live
                livePhotosMap.totalBytes = photoMaps.liveBytes
                allVideosMap.assets = photoMaps.allvideo
                allVideosMap.totalBytes = photoMaps.allvideoBytes
                selfiePhotosMap.assets = photoMaps.selfie
                selfiePhotosMap.totalBytes = photoMaps.selfieBytes
                backPhotosMap.assets = photoMaps.back
                backPhotosMap.totalBytes = photoMaps.backBytes
                largeVideosMap.assets = photoMaps.large
                largeVideosMap.totalBytes = photoMaps.largeBytes
                blurryPhotosMap.assets = photoMaps.blurry
                blurryPhotosMap.totalBytes = photoMaps.blurryBytes
                textPhotosMap.assets = photoMaps.text
                textPhotosMap.totalBytes = photoMaps.textBytes
                similarPhotosMap.doubleAssetIDs = photoMaps.similarGroupIds
                similarPhotosMap.doubleAssets = photoMaps.similarGroupModels
                similarPhotosMap.totalBytes = photoMaps.similarBytes
                duplicatePhotosMap.doubleAssetIDs = photoMaps.duplicateGroupIds
                duplicatePhotosMap.doubleAssets = photoMaps.duplicateGroupModels
                duplicatePhotosMap.totalBytes = photoMaps.duplicateBytes
                recalculateTotalStorage()
            }
        }

        if let progressData = try? Data(contentsOf: files.progress),
           let progressSnapshot = try? JSONDecoder().decode(PRProgressSnapshot.self, from: progressData),
           progressSnapshot.dataFormatVersion == kDataFormatVersion {
            self.progress = progressSnapshot
        } else {
            self.progress = nil
        }
    }

    // MARK: - 重算 totalSize 时同步更新 Dashboard
    private func recalculateTotalStorage() {
        let calculatedSize = screenshotPhotosMap.totalBytes + livePhotosMap.totalBytes + allVideosMap.totalBytes + selfiePhotosMap.totalBytes + backPhotosMap.totalBytes +
                similarPhotosMap.totalBytes + blurryPhotosMap.totalBytes + duplicatePhotosMap.totalBytes +
                textPhotosMap.totalBytes + largeVideosMap.totalBytes + similarVideosMap.totalBytes
        if calculatedSize != totalSize { totalSize = calculatedSize }
        updateDashboardMetrics()
    }

    // MARK: - 拉全库（倒序）
    private func fetchAllAssetsReverseOrder() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        fetchAll = fetchResult
        var assetArray: [PHAsset] = []
        assetArray.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { assetItem,_,_ in assetArray.append(assetItem) }
        allAssets = assetArray
        return assetArray
    }

    // MARK: - 主流程：Phase A → B1 并发 → B2 并发 → idle
    private func startOrContinueProcessing() async {
        await MainActor.run { self.state = .loading }

        let segmentCount = await scheduler.calculateSegmentQuantity()
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
            guard let segmentData = await scheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }

            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let screenshots = segmentAssets.filter { $0.mediaType == .image && $0.mediaSubtypes.contains(.photoScreenshot) }
            let livePhotos = segmentAssets.filter { $0.mediaSubtypes.contains(.photoLive) }
            let videos = segmentAssets.filter { $0.mediaType == .video }
            let images = segmentAssets.filter { $0.mediaType == .image }

            @inline(__always)
            func createAssetModels(_ assetArray: [PHAsset]) -> [PRPhotoAssetModel] {
                assetArray.map {
                    let entry = assetEntryMap[$0.localIdentifier]
                    return PRPhotoAssetModel(id: $0.localIdentifier, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
                }
            }

            let cameraSplitResult = await self.categorizePhotosByCameraType(in: images)
            let selfieModels: [PRPhotoAssetModel] = cameraSplitResult.frontCamera.map {
                let entry = assetEntryMap[$0]
                return PRPhotoAssetModel(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }
            let backModels: [PRPhotoAssetModel] = cameraSplitResult.rearCamera.map {
                let entry = assetEntryMap[$0]
                return PRPhotoAssetModel(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.screenshot, newModels: createAssetModels(screenshots))
                self.mergeSingleCategoryAssets(.livePhoto, newModels: createAssetModels(livePhotos))
                self.mergeSingleCategoryAssets(.allvideo, newModels: createAssetModels(videos))
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
            guard let segmentData = await scheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let similarityClusters = await PRSimilarAnalyzer.locateAnalogousAssetClusters(in: segmentAssets)

            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let clusterModels: [[PRPhotoAssetModel]] = similarityClusters.compactMap { clusterIdentifiers in
                let modelArray = clusterIdentifiers.map { identifier -> PRPhotoAssetModel in
                    let entry = assetEntryMap[identifier]
                    return PRPhotoAssetModel(id: identifier, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
                }
                return modelArray.count >= 2 ? modelArray : nil
            }

            await MainActor.run {
                self.mergeGroupedAssets(.similarphoto, newGroupIDs: similarityClusters, newGroupModels: clusterModels)
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
            guard let segmentData = await scheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let duplicateClusters = await PRDuplicateAnalyzer.isolateRedundantClusters(in: segmentAssets)

            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let clusterModels: [[PRPhotoAssetModel]] = duplicateClusters.compactMap { clusterIdentifiers in
                let modelArray = clusterIdentifiers.map { identifier -> PRPhotoAssetModel in
                    let entry = assetEntryMap[identifier]
                    return PRPhotoAssetModel(id: identifier, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
                }
                return modelArray.count >= 2 ? modelArray : nil
            }

            await MainActor.run {
                self.mergeGroupedAssets(.duplicatephoto, newGroupIDs: duplicateClusters, newGroupModels: clusterModels)
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
            guard let segmentData = await scheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let largeVideoIDs = await PRLargeVideoAnalyzer.detectVoluminousVideoEntities(in: segmentAssets, thresholdBytes: largeVideoThreshold)
            let largeVideoModels: [PRPhotoAssetModel] = largeVideoIDs.map {
                let entry = assetEntryMap[$0]
                return PRPhotoAssetModel(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.largevideo, newModels: largeVideoModels)
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
            guard let segmentData = await scheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let blurryImageIDs = await PRBlurryAnalyzer.scanForLowResolutionEntities(in: segmentAssets)
            let blurryModels: [PRPhotoAssetModel] = blurryImageIDs.map {
                let entry = assetEntryMap[$0]
                return PRPhotoAssetModel(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.blurryphoto, newModels: blurryModels)
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
            guard let segmentData = await scheduler.materializeSegmentAtIndex(index: segmentIndex) else { continue }
            let segmentIdentifiers = segmentData.entries.map(\.assetIdentifier)
            let assetEntryMap = Dictionary(uniqueKeysWithValues: segmentData.entries.map { ($0.assetIdentifier, $0) })
            let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()

            let textImageIDs = await PRTextAnalyzer.detectGlyphBearingEntities(in: segmentAssets)
            let textModels: [PRPhotoAssetModel] = textImageIDs.map {
                let entry = assetEntryMap[$0]
                return PRPhotoAssetModel(id: $0, bytes: entry?.storageSize ?? 0, date: entry?.creationTimestamp ?? 0)
            }

            await MainActor.run {
                self.mergeSingleCategoryAssets(.textphoto, newModels: textModels)
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
    private func mergeSingleCategoryAssets(_ category: PRPhotoCategory, newModels: [PRPhotoAssetModel]) {
        guard !newModels.isEmpty else { return }

        func addUniqueModels(_ incomingModels: [PRPhotoAssetModel], to existingArray: inout [PRPhotoAssetModel]) -> Int64 {
            var existingIDs = Set(existingArray.map(\.assetIdentifier))
            var sizeIncrease: Int64 = 0
            for model in incomingModels where existingIDs.insert(model.assetIdentifier).inserted {
                existingArray.append(model)
                sizeIncrease &+= model.storageSize
            }
            return sizeIncrease
        }

        switch category {
        case .screenshot:
            screenshotPhotosMap.totalBytes &+= addUniqueModels(newModels, to: &screenshotPhotosMap.assets)
        case .livePhoto:
            livePhotosMap.totalBytes &+= addUniqueModels(newModels, to: &livePhotosMap.assets)
        case .allvideo:
            allVideosMap.totalBytes &+= addUniqueModels(newModels, to: &allVideosMap.assets)
        case .selfiephoto:
            selfiePhotosMap.totalBytes &+= addUniqueModels(newModels, to: &selfiePhotosMap.assets)
        case .backphoto:
            backPhotosMap.totalBytes &+= addUniqueModels(newModels, to: &backPhotosMap.assets)
        case .blurryphoto:
            blurryPhotosMap.totalBytes &+= addUniqueModels(newModels, to: &blurryPhotosMap.assets)
        case .textphoto:
            textPhotosMap.totalBytes &+= addUniqueModels(newModels, to: &textPhotosMap.assets)
        case .largevideo:
            largeVideosMap.totalBytes &+= addUniqueModels(newModels, to: &largeVideosMap.assets)
        default: break
        }
    }

    @MainActor
    private func mergeGroupedAssets(
        _ category: PRPhotoCategory,
        newGroupIDs: [[String]],
        newGroupModels: [[PRPhotoAssetModel]]
    ) {
        guard category == .similarphoto || category == .duplicatephoto else { return }
        guard !newGroupIDs.isEmpty else { return }

        if category == .similarphoto {
            similarPhotosMap.doubleAssetIDs = PRGroupMerge.mergeAssetGroups(existingGroups: similarPhotosMap.doubleAssetIDs, newGroups: newGroupIDs)
        } else {
            duplicatePhotosMap.doubleAssetIDs = PRGroupMerge.mergeAssetGroups(existingGroups: duplicatePhotosMap.doubleAssetIDs, newGroups: newGroupIDs)
        }

        func buildModelLookup(existingGroups: [[PRPhotoAssetModel]], newGroups: [[PRPhotoAssetModel]]) -> [String: PRPhotoAssetModel] {
            var modelLookup: [String: PRPhotoAssetModel] = [:]
            modelLookup.reserveCapacity(existingGroups.reduce(0){$0+$1.count} + newGroups.reduce(0){$0+$1.count})
            for model in existingGroups.flatMap({$0}) where modelLookup[model.assetIdentifier] == nil {
                modelLookup[model.assetIdentifier] = model
            }
            for model in newGroups.flatMap({$0}) where modelLookup[model.assetIdentifier] == nil {
                modelLookup[model.assetIdentifier] = model
            }
            return modelLookup
        }

        func rebuildGroupsAndCalculateSizeChange(map: inout PRPhotoAssetsMap, additionalModels: [[PRPhotoAssetModel]]) -> Int64 {
            let previousIDs = Set(map.doubleAssets.flatMap { $0.map(\.assetIdentifier) })
            let modelLookup = buildModelLookup(existingGroups: map.doubleAssets, newGroups: additionalModels)

            let updatedGroups: [[PRPhotoAssetModel]] = map.doubleAssetIDs.compactMap { idArray in
                let models = idArray.compactMap { modelLookup[$0] }.sorted(by: {$0.storageSize > $1.storageSize})
                return models.count >= 2 ? models : nil
            }
            map.doubleAssets = updatedGroups

            let currentIDs = Set(updatedGroups.flatMap { $0.map(\.assetIdentifier) })
            let addedIDs = currentIDs.subtracting(previousIDs)
            let sizeLookup = Dictionary(uniqueKeysWithValues: modelLookup.map { ($0.key, $0.value.storageSize) })
            return addedIDs.reduce(Int64(0)) { $0 &+ (sizeLookup[$1] ?? 0) }
        }

        if category == .similarphoto {
            let sizeDelta = rebuildGroupsAndCalculateSizeChange(map: &similarPhotosMap, additionalModels: newGroupModels)
            similarPhotosMap.totalBytes &+= sizeDelta
        } else {
            let sizeDelta = rebuildGroupsAndCalculateSizeChange(map: &duplicatePhotosMap, additionalModels: newGroupModels)
            duplicatePhotosMap.totalBytes &+= sizeDelta
        }

        recalculateTotalStorage()
    }

    // MARK: - 持久化
    @MainActor
    private func saveCurrentStateToDisk(forceWrite: Bool = false) {
        let mapSnapshot = PRMapsSnapshot(
            screenshot: screenshotPhotosMap.assets,
            screenshotBytes: screenshotPhotosMap.totalBytes,
            live: livePhotosMap.assets,
            liveBytes: livePhotosMap.totalBytes,
            allvideo: allVideosMap.assets,
            allvideoBytes: allVideosMap.totalBytes,
            selfie: selfiePhotosMap.assets,
            selfieBytes: selfiePhotosMap.totalBytes,
            back: backPhotosMap.assets,
            backBytes: backPhotosMap.totalBytes,
            large: largeVideosMap.assets,
            largeBytes: largeVideosMap.totalBytes,
            blurry: blurryPhotosMap.assets,
            blurryBytes: blurryPhotosMap.totalBytes,
            text: textPhotosMap.assets,
            textBytes: textPhotosMap.totalBytes,
            similarGroupIds: similarPhotosMap.doubleAssetIDs,
            similarGroupModels: similarPhotosMap.doubleAssets,
            similarBytes: similarPhotosMap.totalBytes,
            duplicateGroupIds: duplicatePhotosMap.doubleAssetIDs,
            duplicateGroupModels: duplicatePhotosMap.doubleAssets,
            duplicateBytes: duplicatePhotosMap.totalBytes,
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

    private func ensureProgressSnapshot() -> PRProgressSnapshot {
        if let existingProgress = progress { return existingProgress }
        let newProgress = PRProgressSnapshot(
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
                func removeFromArray(_ array: inout [PRPhotoAssetModel]) -> Int64 {
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

                screenshotPhotosMap.totalBytes &-= removeFromArray(&screenshotPhotosMap.assets)
                livePhotosMap.totalBytes &-= removeFromArray(&livePhotosMap.assets)
                allVideosMap.totalBytes &-= removeFromArray(&allVideosMap.assets)
                selfiePhotosMap.totalBytes &-= removeFromArray(&selfiePhotosMap.assets)
                backPhotosMap.totalBytes &-= removeFromArray(&backPhotosMap.assets)
                largeVideosMap.totalBytes &-= removeFromArray(&largeVideosMap.assets)
                blurryPhotosMap.totalBytes &-= removeFromArray(&blurryPhotosMap.assets)
                textPhotosMap.totalBytes &-= removeFromArray(&textPhotosMap.assets)
                
                let duplicateRemovedSize = filterAssetsFromGroupedMap(&duplicatePhotosMap, removing: removedIDs)
                duplicatePhotosMap.totalBytes &-= duplicateRemovedSize
                let similarRemovedSize = filterAssetsFromGroupedMap(&similarPhotosMap, removing: removedIDs)
                similarPhotosMap.totalBytes &-= similarRemovedSize

                recalculateTotalStorage()
                self.saveCurrentStateToDisk()
            }
        }
    }

    @MainActor
    private func filterAssetsFromGroupedMap(_ map: inout PRPhotoAssetsMap, removing identifiers: Set<String>) -> Int64 {
        var removedSize: Int64 = 0
        for group in map.doubleAssets {
            for model in group where identifiers.contains(model.assetIdentifier) {
                removedSize &+= model.storageSize
            }
        }
        for i in map.doubleAssets.indices {
            map.doubleAssets[i].removeAll { identifiers.contains($0.assetIdentifier) }
        }
        map.doubleAssets.removeAll { $0.count < 2 }
        for i in map.doubleAssetIDs.indices {
            map.doubleAssetIDs[i].removeAll { identifiers.contains($0) }
        }
        map.doubleAssetIDs.removeAll { $0.count < 2 }
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
extension PRPhotoMapManager: PHPhotoLibraryChangeObserver {

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let baseFetch = fetchAll,
              let changeDetails = changeInstance.changeDetails(for: baseFetch) else { return }

        guard changeDetails.hasIncrementalChanges else {
            Task { self.refreshAssetRepositoryAndInitiateSequence() }
            return
        }

        let afterFetch = changeDetails.fetchResultAfterChanges
        self.fetchAll = afterFetch
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
        func createAssetModel(_ asset: PHAsset) -> PRPhotoAssetModel {
            let bytes = computeResourceVolume(asset)
            let date = Int64((asset.creationDate ?? .distantPast).timeIntervalSince1970)
            return PRPhotoAssetModel(id: asset.localIdentifier, bytes: bytes, date: date, asset: asset)
        }

        let screenshots = allAssets.filter { $0.mediaType == .image && $0.mediaSubtypes.contains(.photoScreenshot) }.map(createAssetModel)
        let livePhotos = allAssets.filter { $0.mediaSubtypes.contains(.photoLive) }.map(createAssetModel)
        let videos = allAssets.filter { $0.mediaType == .video }.map(createAssetModel)

        await MainActor.run {
            withTransaction(Transaction(animation: nil)) {
                screenshotPhotosMap.assets = screenshots
                screenshotPhotosMap.totalBytes = screenshots.reduce(0) { $0 &+ $1.storageSize }

                livePhotosMap.assets = livePhotos
                livePhotosMap.totalBytes = livePhotos.reduce(0) { $0 &+ $1.storageSize }

                allVideosMap.assets = videos
                allVideosMap.totalBytes = videos.reduce(0) { $0 &+ $1.storageSize }
            }
            recalculateTotalStorage()
        }
    }
}

extension PRPhotoMapManager {
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
extension PRPhotoMapManager {
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
