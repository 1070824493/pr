//
//  PRPhotoMapManager.swift
//  SwiftUITestProject
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
    @Published public private(set) var screenshotPhotosMap = PhotoAssetsMap(.screenshot)
    @Published public private(set) var livePhotosMap = PhotoAssetsMap(.livePhoto)
    @Published public private(set) var selfiePhotosMap = PhotoAssetsMap(.selfiephoto)
    @Published public private(set) var backPhotosMap = PhotoAssetsMap(.backphoto)
    @Published public private(set) var allVideosMap = PhotoAssetsMap(.allvideo)
    // 分组/重型类目
    @Published public private(set) var similarPhotosMap = PhotoAssetsMap(.similarphoto)
    @Published public private(set) var blurryPhotosMap = PhotoAssetsMap(.blurryphoto)
    @Published public private(set) var duplicatePhotosMap = PhotoAssetsMap(.duplicatephoto)
    @Published public private(set) var textPhotosMap = PhotoAssetsMap(.textphoto)
    @Published public private(set) var largeVideosMap = PhotoAssetsMap(.largevideo)
    @Published public private(set) var similarVideosMap = PhotoAssetsMap(.similarvideo) // 预留
    
    @Published public private(set) var dashboard: PRDashboardSnapshot?

    // 删除广播（外部写入触发即时扣减）
    @Published public var lastDeleteAssets: [PHAsset] = [] {
        didSet {
            let d = lastDeleteAssets
            guard !d.isEmpty else { return }
            Task { @MainActor in self.applyRemovedAssetsToMaps(d) }
        }
    }

    // 权限弹窗
    @Published public var permissionAlert: AlertModalModel?
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
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ck_photo_v3")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.files = PRCacheFiles(dir: dir)
        self.scheduler = PRChunkScheduler(chunkSize: 500, files: files)
        super.init()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - 对外入口
    /// 重新加载全库并启动分析管线（含缓存秒显）
    public func reloadAll() {
        requestPermission { [weak self] ok in
            guard let self else { return }
            guard ok else {
                self.state = .noPermission
                return
            }
            PHPhotoLibrary.shared().register(self)
            Task(priority: .userInitiated) {
                await self.bootFromCacheIfAny() // 秒显缓存
                let all = self.fetchAllAssetsSortedDesc()
                await self.scheduler.configureSnapshot(with: all)
                await self.startOrResumeBlockPipeline()
            }
        }
    }

    /// 申请相册读写权限，失败时弹出前往设置提示
    public func requestPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] s in
            DispatchQueue.main.async {
                guard let self else { return }
                if s == .authorized || s == .limited {
                    completion(true)
                } else {
                    self.state = .noPermission
                    self.presentSettingsAlert(for: s)
                    completion(false)
                }
            }
        }
    }
    
    @MainActor private func repIdFor(_ map: PhotoAssetsMap) -> [String] {
        let ids = map.assets.prefix(2).map({$0.photoIdentifier})
        if !ids.isEmpty {
            return ids
        }
        
        let doubleAssetsIds = map.doubleAssets.prefix(2).compactMap({$0.first?.photoIdentifier})
        if !doubleAssetsIds.isEmpty {
            return doubleAssetsIds
        }
        
        let doubleAssetIDs = map.doubleAssetIDs.prefix(2).compactMap({$0.first})
        if !doubleAssetIDs.isEmpty {
            return doubleAssetIDs
        }
        
        return []
    }

    @MainActor private func buildDashboard() -> PRDashboardSnapshot {
        let cells: [PRDashboardCell] = [
            PRDashboardCell(category: .screenshot,   bytes: screenshotPhotosMap.totalBytes,   repID: repIdFor(screenshotPhotosMap), count: screenshotPhotosMap.assets.count),
            PRDashboardCell(category: .livePhoto,    bytes: livePhotosMap.totalBytes,         repID: repIdFor(livePhotosMap), count: livePhotosMap.assets.count),
            PRDashboardCell(category: .selfiephoto,  bytes: selfiePhotosMap.totalBytes,       repID: repIdFor(selfiePhotosMap), count: selfiePhotosMap.assets.count),
            PRDashboardCell(category: .backphoto,    bytes: backPhotosMap.totalBytes,         repID: repIdFor(backPhotosMap), count: backPhotosMap.assets.count),
            PRDashboardCell(category: .allvideo,     bytes: allVideosMap.totalBytes,          repID: repIdFor(allVideosMap), count: allVideosMap.assets.count),
            PRDashboardCell(category: .largevideo,   bytes: largeVideosMap.totalBytes,        repID: repIdFor(largeVideosMap), count: largeVideosMap.assets.count),
            PRDashboardCell(category: .blurryphoto,  bytes: blurryPhotosMap.totalBytes,       repID: repIdFor(blurryPhotosMap), count: blurryPhotosMap.assets.count),
            PRDashboardCell(category: .textphoto,    bytes: textPhotosMap.totalBytes,         repID: repIdFor(textPhotosMap), count: textPhotosMap.assets.count),
            PRDashboardCell(category: .similarphoto, bytes: similarPhotosMap.totalBytes,      repID: repIdFor(similarPhotosMap), count: similarPhotosMap.assets.count),
            PRDashboardCell(category: .duplicatephoto, bytes: duplicatePhotosMap.totalBytes,  repID: repIdFor(duplicatePhotosMap), count: duplicatePhotosMap.assets.count)
        ]
        return PRDashboardSnapshot(cells: cells, totalSize: totalSize, updatedAt: Date())
    }

    @MainActor private func saveDashboard(_ snap: PRDashboardSnapshot) {
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: files.dashboard, options: .atomic)
        }
    }

    @MainActor private func loadDashboardIfAny() -> PRDashboardSnapshot? {
        if let data = try? Data(contentsOf: files.dashboard),
           let d = try? JSONDecoder().decode(PRDashboardSnapshot.self, from: data) {
            return d
        }
        return nil
    }

    private func updateDashboard() {
        Task { @MainActor in
            let d = buildDashboard()
            dashboard = d
            saveDashboard(d)
        }
    }

    // MARK: - 秒显缓存
    private func bootFromCacheIfAny() async {
        await MainActor.run { self.state = .loading }

        // Dashboard 优先秒显
        if let dash = await MainActor.run(body: { loadDashboardIfAny() }) {
            await MainActor.run { self.dashboard = dash }
        }

        if let data = try? Data(contentsOf: files.maps),
           let maps = try? JSONDecoder().decode(PRMapsSnapshot.self, from: data),
           maps.bytesSchemaVersion == kBytesSchemaVersion {
            await MainActor.run {
                screenshotPhotosMap.assets = maps.screenshot
//                screenshotPhotosMap.assets = maps.screenshot.sorted { $0.photoDate > $1.photoDate }
                screenshotPhotosMap.totalBytes = maps.screenshotBytes
                livePhotosMap.assets = maps.live
//                livePhotosMap.assets = maps.live.sorted { $0.photoDate > $1.photoDate }
                livePhotosMap.totalBytes = maps.liveBytes
                allVideosMap.assets = maps.allvideo
//                allVideosMap.assets = maps.allvideo.sorted { $0.photoDate > $1.photoDate }
                allVideosMap.totalBytes = maps.allvideoBytes
                selfiePhotosMap.assets = maps.selfie
                selfiePhotosMap.totalBytes = maps.selfieBytes
                backPhotosMap.assets = maps.back
                backPhotosMap.totalBytes = maps.backBytes
                largeVideosMap.assets = maps.large
//                largeVideosMap.assets = maps.large.sorted { $0.photoDate > $1.photoDate }
                largeVideosMap.totalBytes = maps.largeBytes
                blurryPhotosMap.assets = maps.blurry
//                blurryPhotosMap.assets = maps.blurry.sorted { $0.photoDate > $1.photoDate }
                blurryPhotosMap.totalBytes = maps.blurryBytes
                textPhotosMap.assets = maps.text
//                textPhotosMap.assets = maps.text.sorted { $0.photoDate > $1.photoDate }
                textPhotosMap.totalBytes = maps.textBytes
                similarPhotosMap.doubleAssetIDs = maps.similarGroupIds
                similarPhotosMap.doubleAssets = maps.similarGroupModels
                similarPhotosMap.totalBytes = maps.similarBytes
                duplicatePhotosMap.doubleAssetIDs = maps.duplicateGroupIds
                duplicatePhotosMap.doubleAssets = maps.duplicateGroupModels
                duplicatePhotosMap.totalBytes = maps.duplicateBytes
                recomputeTotalSize()
            }
        }

        if let d = try? Data(contentsOf: files.progress),
           let p = try? JSONDecoder().decode(PRProgressSnapshot.self, from: d),
           p.bytesSchemaVersion == kBytesSchemaVersion {
            self.progress = p
        } else {
            self.progress = nil
        }
    }

    // MARK: - 重算 totalSize 时同步更新 Dashboard
    private func recomputeTotalSize() {
        let s = screenshotPhotosMap.totalBytes + livePhotosMap.totalBytes + allVideosMap.totalBytes + selfiePhotosMap.totalBytes + backPhotosMap.totalBytes +
                similarPhotosMap.totalBytes + blurryPhotosMap.totalBytes + duplicatePhotosMap.totalBytes +
                textPhotosMap.totalBytes + largeVideosMap.totalBytes + similarVideosMap.totalBytes
        if s != totalSize { totalSize = s }
        updateDashboard()
    }

    // MARK: - 拉全库（倒序）
    private func fetchAllAssetsSortedDesc() -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let res = PHAsset.fetchAssets(with: opts)
        fetchAll = res
        var arr: [PHAsset] = []
        arr.reserveCapacity(res.count)
        res.enumerateObjects { a,_,_ in arr.append(a) }
        allAssets = arr
        return arr
    }

    // MARK: - 主流程：Phase A → B1 并发 → B2 并发 → idle
    private func startOrResumeBlockPipeline() async {
        await MainActor.run { self.state = .loading }

        let count = await scheduler.chunkCount()
        guard count > 0 else {
            await MainActor.run { self.state = .idle }
            return
        }

        // Phase A：轻量（串行；每块回调 + 节流持久化）
        await runPhaseA(totalChunks: count)

        // Phase B1：相似/重复/大视频（并发；每块回调 + 节流持久化）
        await withTaskGroup(of: Void.self) { g in
            g.addTask { await self.runPhaseB1_Similar(totalChunks: count) }
            g.addTask { await self.runPhaseB1_Duplicate(totalChunks: count) }
            g.addTask { await self.runPhaseB1_Large(totalChunks: count) }
            await g.waitForAll()
        }

        // Phase B2：模糊/文字（并发；每块回调 + 节流持久化）
        await withTaskGroup(of: Void.self) { g in
            g.addTask { await self.runPhaseB2_Blurry(totalChunks: count) }
            g.addTask { await self.runPhaseB2_Text(totalChunks: count) }
            await g.waitForAll()
        }

        await MainActor.run {
            self.saveMapsAndProgress(forceAll: true)
            self.state = .idle
        }
    }

    // MARK: - Phase A：轻量三类
    private func runPhaseA(totalChunks: Int) async {
        let start = (progress?.lastA ?? -1) + 1
        guard start < totalChunks else { return }
        var persistN = 0

        for i in start..<totalChunks {
            guard let chunk = await scheduler.materializeChunk(index: i) else { continue }

            let ids = chunk.entries.map(\.photoIdentifier)
            let entryMap = Dictionary(uniqueKeysWithValues: chunk.entries.map { ($0.photoIdentifier, $0) })
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()

            let shots = assets.filter { $0.mediaType == .image && $0.mediaSubtypes.contains(.photoScreenshot) }
            let lives = assets.filter { $0.mediaSubtypes.contains(.photoLive) }
            let vids = assets.filter { $0.mediaType == .video }
            let imgs = assets.filter { $0.mediaType == .image }

            @inline(__always)
            func toModels(_ arr: [PHAsset]) -> [PhotoAssetModel] {
                arr.map {
                    let e = entryMap[$0.localIdentifier]
                    return PhotoAssetModel(id: $0.localIdentifier, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
                }
            }

            let split = await self.splitFrontBackIDs(in: imgs)
            let selfieModels: [PhotoAssetModel] = split.front.map {
                let e = entryMap[$0]
                return PhotoAssetModel(id: $0, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
            }
            let backModels: [PhotoAssetModel] = split.back.map {
                let e = entryMap[$0]
                return PhotoAssetModel(id: $0, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
            }

            await MainActor.run {
                self.applyAddSingle(.screenshot, add: toModels(shots))
                self.applyAddSingle(.livePhoto, add: toModels(lives))
                self.applyAddSingle(.allvideo, add: toModels(vids))
                self.applyAddSingle(.selfiephoto, add: selfieModels)
                self.applyAddSingle(.backphoto, add: backModels)
                self.recomputeTotalSize()
            }

            progress = ensureProgress()
            progress?.lastA = i
            persistN += 1
            if persistN >= kPersistEveryN {
                persistN = 0
                await MainActor.run { self.saveMapsAndProgress() }
            }
        }

        await MainActor.run { self.saveMapsAndProgress() }
    }

    // MARK: - Phase B1：相似
    private func runPhaseB1_Similar(totalChunks: Int) async {
        let start = (progress?.lastSimilar ?? -1) + 1
        guard start < totalChunks else { return }
        var persistN = 0

        for i in start..<totalChunks {
            guard let chunk = await scheduler.materializeChunk(index: i) else { continue }
            let ids = chunk.entries.map(\.photoIdentifier)
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()

            let groups = await SimilarAnalyzer.analyzeGroupIDs(in: assets)

            let entryMap = Dictionary(uniqueKeysWithValues: chunk.entries.map { ($0.photoIdentifier, $0) })
            let groupModels: [[PhotoAssetModel]] = groups.compactMap { gid in
                let arr = gid.map { id -> PhotoAssetModel in
                    let e = entryMap[id]
                    return PhotoAssetModel(id: id, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
                }
                return arr.count >= 2 ? arr : nil
            }

            await MainActor.run {
                self.applyAddGrouped(.similarphoto, addGroupIDs: groups, addGroupModels: groupModels)
                self.recomputeTotalSize()
            }

            progress = ensureProgress()
            progress?.lastSimilar = i
            persistN += 1
            if persistN >= kPersistEveryN {
                persistN = 0
                await MainActor.run { self.saveMapsAndProgress() }
            }
        }

        await MainActor.run { self.saveMapsAndProgress() }
    }

    // MARK: - Phase B1：重复
    private func runPhaseB1_Duplicate(totalChunks: Int) async {
        let start = (progress?.lastDuplicate ?? -1) + 1
        guard start < totalChunks else { return }
        var persistN = 0

        for i in start..<totalChunks {
            guard let chunk = await scheduler.materializeChunk(index: i) else { continue }
            let ids = chunk.entries.map(\.photoIdentifier)
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()

            let groups = await DuplicateAnalyzer.analyzeGroupIDs(in: assets)

            let entryMap = Dictionary(uniqueKeysWithValues: chunk.entries.map { ($0.photoIdentifier, $0) })
            let groupModels: [[PhotoAssetModel]] = groups.compactMap { gid in
                let arr = gid.map { id -> PhotoAssetModel in
                    let e = entryMap[id]
                    return PhotoAssetModel(id: id, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
                }
                return arr.count >= 2 ? arr : nil
            }

            await MainActor.run {
                self.applyAddGrouped(.duplicatephoto, addGroupIDs: groups, addGroupModels: groupModels)
                self.recomputeTotalSize()
            }

            progress = ensureProgress()
            progress?.lastDuplicate = i
            persistN += 1
            if persistN >= kPersistEveryN {
                persistN = 0
                await MainActor.run { self.saveMapsAndProgress() }
            }
        }

        await MainActor.run { self.saveMapsAndProgress() }
    }

    // MARK: - Phase B1：大视频
    private func runPhaseB1_Large(totalChunks: Int) async {
        let start = (progress?.lastLarge ?? -1) + 1
        guard start < totalChunks else { return }
        var persistN = 0

        for i in start..<totalChunks {
            guard let chunk = await scheduler.materializeChunk(index: i) else { continue }
            let ids = chunk.entries.map(\.photoIdentifier)
            let entryMap = Dictionary(uniqueKeysWithValues: chunk.entries.map { ($0.photoIdentifier, $0) })
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()

            let idList = await LargeVideoAnalyzer.analyzeIDs(in: assets, thresholdBytes: largeVideoThreshold)
            let models: [PhotoAssetModel] = idList.map {
                let e = entryMap[$0]
                return PhotoAssetModel(id: $0, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
            }

            await MainActor.run {
                self.applyAddSingle(.largevideo, add: models)
                self.recomputeTotalSize()
            }

            progress = ensureProgress()
            progress?.lastLarge = i
            persistN += 1
            if persistN >= kPersistEveryN {
                persistN = 0
                await MainActor.run { self.saveMapsAndProgress() }
            }
        }

        await MainActor.run { self.saveMapsAndProgress() }
    }

    // MARK: - Phase B2：模糊
    private func runPhaseB2_Blurry(totalChunks: Int) async {
        let start = (progress?.lastBlurry ?? -1) + 1
        guard start < totalChunks else { return }
        var persistN = 0

        for i in start..<totalChunks {
            guard let chunk = await scheduler.materializeChunk(index: i) else { continue }
            let ids = chunk.entries.map(\.photoIdentifier)
            let entryMap = Dictionary(uniqueKeysWithValues: chunk.entries.map { ($0.photoIdentifier, $0) })
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()

            let idList = await BlurryAnalyzer.analyzeIDs(in: assets)
            let models: [PhotoAssetModel] = idList.map {
                let e = entryMap[$0]
                return PhotoAssetModel(id: $0, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
            }

            await MainActor.run {
                self.applyAddSingle(.blurryphoto, add: models)
                self.recomputeTotalSize()
            }

            progress = ensureProgress()
            progress?.lastBlurry = i
            persistN += 1
            if persistN >= kPersistEveryN {
                persistN = 0
                await MainActor.run { self.saveMapsAndProgress() }
            }
        }

        await MainActor.run { self.saveMapsAndProgress() }
    }

    // MARK: - Phase B2：文字
    private func runPhaseB2_Text(totalChunks: Int) async {
        let start = (progress?.lastText ?? -1) + 1
        guard start < totalChunks else { return }
        var persistN = 0

        for i in start..<totalChunks {
            guard let chunk = await scheduler.materializeChunk(index: i) else { continue }
            let ids = chunk.entries.map(\.photoIdentifier)
            let entryMap = Dictionary(uniqueKeysWithValues: chunk.entries.map { ($0.photoIdentifier, $0) })
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()

            let idList = await TextAnalyzer.analyzeIDs(in: assets)
            let models: [PhotoAssetModel] = idList.map {
                let e = entryMap[$0]
                return PhotoAssetModel(id: $0, bytes: e?.photoBytes ?? 0, date: e?.photoDate ?? 0)
            }

            await MainActor.run {
                self.applyAddSingle(.textphoto, add: models)
                self.recomputeTotalSize()
            }

            progress = ensureProgress()
            progress?.lastText = i
            persistN += 1
            if persistN >= kPersistEveryN {
                persistN = 0
                await MainActor.run { self.saveMapsAndProgress() }
            }
        }

        await MainActor.run { self.saveMapsAndProgress() }
    }

    // MARK: - 合并 & 统计（主线程）
    @MainActor
    private func applyAddSingle(_ cat: PhotoCategory, add models: [PhotoAssetModel]) {
        guard !models.isEmpty else { return }

        func insertUnique(_ add: [PhotoAssetModel], into arr: inout [PhotoAssetModel]) -> Int64 {
            var seen = Set(arr.map(\.photoIdentifier))
            var addedBytes: Int64 = 0
            for m in add where seen.insert(m.photoIdentifier).inserted {
                arr.append(m)
                addedBytes &+= m.photoBytes
            }
//            arr.sort { $0.photoDate < $1.photoDate }
            return addedBytes
        }

        switch cat {
        case .screenshot:
            screenshotPhotosMap.totalBytes &+= insertUnique(models, into: &screenshotPhotosMap.assets)
        case .livePhoto:
            livePhotosMap.totalBytes &+= insertUnique(models, into: &livePhotosMap.assets)
        case .allvideo:
            allVideosMap.totalBytes &+= insertUnique(models, into: &allVideosMap.assets)
        case .selfiephoto:
            selfiePhotosMap.totalBytes &+= insertUnique(models, into: &selfiePhotosMap.assets)
        case .backphoto:
            backPhotosMap.totalBytes &+= insertUnique(models, into: &backPhotosMap.assets)
        case .blurryphoto:
            blurryPhotosMap.totalBytes &+= insertUnique(models, into: &blurryPhotosMap.assets)
        case .textphoto:
            textPhotosMap.totalBytes &+= insertUnique(models, into: &textPhotosMap.assets)
        case .largevideo:
            largeVideosMap.totalBytes &+= insertUnique(models, into: &largeVideosMap.assets)
        default: break
        }
    }

    @MainActor
    private func applyAddGrouped(
        _ cat: PhotoCategory,
        addGroupIDs: [[String]],
        addGroupModels: [[PhotoAssetModel]]
    ) {
        guard cat == .similarphoto || cat == .duplicatephoto else { return }
        guard !addGroupIDs.isEmpty else { return }

        if cat == .similarphoto {
            similarPhotosMap.doubleAssetIDs = GroupMerge.merge(existing: similarPhotosMap.doubleAssetIDs, adding: addGroupIDs)
        } else {
            duplicatePhotosMap.doubleAssetIDs = GroupMerge.merge(existing: duplicatePhotosMap.doubleAssetIDs, adding: addGroupIDs)
        }

        func buildIndex(existing: [[PhotoAssetModel]], adding: [[PhotoAssetModel]]) -> [String: PhotoAssetModel] {
            var dict: [String: PhotoAssetModel] = [:]
            dict.reserveCapacity(existing.reduce(0){$0+$1.count} + adding.reduce(0){$0+$1.count})
            for m in existing.flatMap({$0}) where dict[m.photoIdentifier] == nil {
                dict[m.photoIdentifier] = m
            }
            for m in adding.flatMap({$0}) where dict[m.photoIdentifier] == nil {
                dict[m.photoIdentifier] = m
            }
            return dict
        }

        func rebuildAndCountDelta(map: inout PhotoAssetsMap, addModels: [[PhotoAssetModel]]) -> Int64 {
            let oldIDs = Set(map.doubleAssets.flatMap { $0.map(\.photoIdentifier) })
            let index = buildIndex(existing: map.doubleAssets, adding: addModels)

            let newGroups: [[PhotoAssetModel]] = map.doubleAssetIDs.compactMap { ids in
                let arr = ids.compactMap { index[$0] }.sorted(by: {$0.photoBytes > $1.photoBytes})
                return arr.count >= 2 ? arr : nil
            }
            map.doubleAssets = newGroups

            let newIDs = Set(newGroups.flatMap { $0.map(\.photoIdentifier) })
            let deltaIDs = newIDs.subtracting(oldIDs)
            let bytesIndex = Dictionary(uniqueKeysWithValues: index.map { ($0.key, $0.value.photoBytes) })
            return deltaIDs.reduce(Int64(0)) { $0 &+ (bytesIndex[$1] ?? 0) }
        }

        if cat == .similarphoto {
            let delta = rebuildAndCountDelta(map: &similarPhotosMap, addModels: addGroupModels)
            similarPhotosMap.totalBytes &+= delta
        } else {
            let delta = rebuildAndCountDelta(map: &duplicatePhotosMap, addModels: addGroupModels)
            duplicatePhotosMap.totalBytes &+= delta
        }

        recomputeTotalSize()
    }

    // MARK: - 持久化
    @MainActor
    private func saveMapsAndProgress(forceAll: Bool = false) {
        let snap = PRMapsSnapshot(
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
            bytesSchemaVersion: kBytesSchemaVersion,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: files.maps, options: .atomic)
        }

        var p = ensureProgress()
        if forceAll {
            p.updatedAt = Date()
            progress = p
        } else {
            progress?.updatedAt = Date()
            p = progress ?? p
        }
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: files.progress, options: .atomic)
        }
    }

    private func ensureProgress() -> PRProgressSnapshot {
        if let p = progress { return p }
        let p = PRProgressSnapshot(
            snapshotHash: "hash-\(UUID().uuidString)",
            lastA: -1,
            lastSimilar: -1,
            lastDuplicate: -1,
            lastLarge: -1,
            lastBlurry: -1,
            lastText: -1,
            bytesSchemaVersion: kBytesSchemaVersion,
            updatedAt: Date()
        )
        progress = p
        return p
    }

    // MARK: - 删除应用（精确字节扣减）
    /// 将外部删除的资产应用到各类目地图中（精确字节扣减）
    public func applyRemovedAssetsToMaps(_ removed: [PHAsset]) {
        let ids = Set(removed.map { $0.localIdentifier })
        guard !ids.isEmpty else { return }

        Task { @MainActor in
            withTransaction(Transaction(animation: nil)) {
                func strip(_ arr: inout [PhotoAssetModel]) -> Int64 {
                    var delta: Int64 = 0
                    arr.removeAll { m in
                        if ids.contains(m.photoIdentifier) {
                            delta &+= m.photoBytes
                            return true
                        }
                        return false
                    }
                    return delta
                }

                screenshotPhotosMap.totalBytes &-= strip(&screenshotPhotosMap.assets)
                livePhotosMap.totalBytes &-= strip(&livePhotosMap.assets)
                allVideosMap.totalBytes &-= strip(&allVideosMap.assets)
                selfiePhotosMap.totalBytes &-= strip(&selfiePhotosMap.assets)
                backPhotosMap.totalBytes &-= strip(&backPhotosMap.assets)
                largeVideosMap.totalBytes &-= strip(&largeVideosMap.assets)
                blurryPhotosMap.totalBytes &-= strip(&blurryPhotosMap.assets)
                textPhotosMap.totalBytes &-= strip(&textPhotosMap.assets)

                let dupRemoved = stripGroupsInPlace(&duplicatePhotosMap, removing: ids)
                duplicatePhotosMap.totalBytes &-= dupRemoved
                let simRemoved = stripGroupsInPlace(&similarPhotosMap, removing: ids)
                similarPhotosMap.totalBytes &-= simRemoved

                recomputeTotalSize()
                self.saveMapsAndProgress()
            }
        }
    }

    @MainActor
    private func stripGroupsInPlace(_ map: inout PhotoAssetsMap, removing ids: Set<String>) -> Int64 {
        var removedBytes: Int64 = 0
        for gi in map.doubleAssets.indices {
            for m in map.doubleAssets[gi] where ids.contains(m.photoIdentifier) {
                removedBytes &+= m.photoBytes
            }
        }
        for gi in map.doubleAssets.indices {
            map.doubleAssets[gi].removeAll { ids.contains($0.photoIdentifier) }
        }
        map.doubleAssets.removeAll { $0.count < 2 }
        for gi in map.doubleAssetIDs.indices {
            map.doubleAssetIDs[gi].removeAll { ids.contains($0) }
        }
        map.doubleAssetIDs.removeAll { $0.count < 2 }
        return removedBytes
    }

    // MARK: - 运行期：解析 PHAsset
    /// 解析并缓存单个 `PHAsset`（存在即取缓存，未命中则查询）
    public func resolvePHAsset(for id: String) -> PHAsset? {
        if let a = assetCache.object(forKey: id as NSString) { return a }
        let arr = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).toArray()
        if let a = arr.first {
            assetCache.setObject(a, forKey: id as NSString)
            return a
        }
        return nil
    }
}

// MARK: - PHPhotoLibraryChangeObserver（增量处理）
extension PRPhotoMapManager: PHPhotoLibraryChangeObserver {

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let base = fetchAll,
              let details = changeInstance.changeDetails(for: base) else { return }

        guard details.hasIncrementalChanges else {
            Task { self.reloadAll() }
            return
        }

        let after = details.fetchResultAfterChanges
        self.fetchAll = after
        let afterArray = after.toArray()

        var inserted: [PHAsset] = []
        var removed: [PHAsset] = []
        var changed: [PHAsset] = []

        if let ins = details.insertedIndexes { inserted = ins.map { after.object(at: $0) } }
        if let rem = details.removedIndexes { removed = rem.map { base.object(at: $0) } }
        if let chg = details.changedIndexes { changed = chg.map { after.object(at: $0) } }

        Task { @MainActor in self.state = .loading }

        if !removed.isEmpty {
            self.applyRemovedAssetsToMaps(removed)
            return
        }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.rebuildLightFrom(afterArray)
            await MainActor.run {
                self.saveMapsAndProgress()
                self.state = .idle
            }
        }
    }

    private func rebuildLightFrom(_ all: [PHAsset]) async {
        @inline(__always)
        func toModel(_ a: PHAsset) -> PhotoAssetModel {
            let bytes = assetSizeBytes(a)
            let date = Int64((a.creationDate ?? .distantPast).timeIntervalSince1970)
            return PhotoAssetModel(id: a.localIdentifier, bytes: bytes, date: date, asset: a)
        }

        let shots = all.filter { $0.mediaType == .image && $0.mediaSubtypes.contains(.photoScreenshot) }.map(toModel)
        let lives = all.filter { $0.mediaSubtypes.contains(.photoLive) }.map(toModel)
        let vids = all.filter { $0.mediaType == .video }.map(toModel)

        await MainActor.run {
            withTransaction(Transaction(animation: nil)) {
                screenshotPhotosMap.assets = shots
                screenshotPhotosMap.totalBytes = shots.reduce(0) { $0 &+ $1.photoBytes }

                livePhotosMap.assets = lives
                livePhotosMap.totalBytes = lives.reduce(0) { $0 &+ $1.photoBytes }

                allVideosMap.assets = vids
                allVideosMap.totalBytes = vids.reduce(0) { $0 &+ $1.photoBytes }
            }
            recomputeTotalSize()
        }
    }
}

extension PRPhotoMapManager {
    private enum CameraFacing { case front, back }
    private func cameraFacing(for asset: PHAsset) async -> CameraFacing? {
        guard asset.mediaType == .image else { return nil }
        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = false
        opts.version = .current
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                guard let data = data else { cont.resume(returning: nil); return }
                guard let src = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(src) > 0 else { cont.resume(returning: nil); return }
                guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { cont.resume(returning: nil); return }
                var facing: CameraFacing?
                if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                    if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                        let l = lens.lowercased()
                        if l.contains("front") { facing = .front }
                        else if l.contains("back") || l.contains("rear") { facing = .back }
                    }
                }
                if facing == nil, let maker = props[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any] {
                    if let camType = maker["CameraType" as CFString] as? String {
                        let c = camType.lowercased()
                        if c.contains("front") { facing = .front }
                        else if c.contains("back") || c.contains("rear") { facing = .back }
                    }
                }
                cont.resume(returning: facing)
            }
        }
    }

    private func splitFrontBackIDs(in assets: [PHAsset]) async -> (front: [String], back: [String]) {
        var front: [String] = []
        var back: [String] = []
        await withTaskGroup(of: (String, CameraFacing?).self) { g in
            for a in assets { g.addTask { (a.localIdentifier, await self.cameraFacing(for: a)) } }
            for await (id, f) in g {
                if let f = f {
                    if f == .front { front.append(id) } else { back.append(id) }
                }
            }
        }
        return (front, back)
    }
}
