//
//  PRChunkScheduler.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos

/// 分块调度器（actor）
/// - 职责: 根据快照资产列表生成固定大小的块，物化每块并缓存到磁盘
/// - 并发: `actor` 保证内部状态串行化
actor PRChunkScheduler {
    let chunkSize: Int
    private let files: PRCacheFiles
    private var allIds: [String] = []
    private(set) var snapshotHash: String = ""

    init(chunkSize: Int, files: PRCacheFiles) {
        self.chunkSize = chunkSize
        self.files = files
    }

    func configureSnapshotParameters(with assetsDesc: [PHAsset]) {
        allIds = assetsDesc.map(\.localIdentifier)
        snapshotHash = "\(allIds.hashValue)_\(allIds.count)"
    }

    func calculateSegmentQuantity() -> Int {
        guard !allIds.isEmpty else { return 0 }
        return (allIds.count + chunkSize - 1) / chunkSize
    }

    func materializeSegmentAtIndex(index: Int) -> PRChunkSnapshot? {
        guard index >= 0, index < calculateSegmentQuantity() else { return nil }
        let u = files.locateSegmentFile(index)

        if let data = try? Data(contentsOf: u),
           let s = try? JSONDecoder().decode(PRChunkSnapshot.self, from: data) {
            return s
        }

        let lo = index * chunkSize
        let hi = min(lo + chunkSize, allIds.count)
        let ids = Array(allIds[lo..<hi])

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).toArray()
        var dateMap: [String:Int64] = [:]
        var sizeMap: [String:Int64] = [:]
        dateMap.reserveCapacity(assets.count)
        sizeMap.reserveCapacity(assets.count)

        for a in assets {
            dateMap[a.localIdentifier] = Int64((a.creationDate ?? .distantPast).timeIntervalSince1970)
            sizeMap[a.localIdentifier] = computeResourceVolume(a)
        }

        var entries = [PRPhotoAssetModel](); entries.reserveCapacity(ids.count)
        for id in ids {
            entries.append(.init(id: id, bytes: sizeMap[id] ?? 0, date: dateMap[id] ?? 0))
        }

        let snap = PRChunkSnapshot(index: index, entries: entries)
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: u, options: .atomic) }
        return snap
    }
}

