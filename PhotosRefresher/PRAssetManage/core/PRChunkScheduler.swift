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
    private let fileManager: PRCacheFiles
    private var assetIdentifiers: [String] = []
    private(set) var snapshotIdentifier: String = ""

    init(chunkSize: Int, files: PRCacheFiles) {
        self.chunkSize = chunkSize
        self.fileManager = files
    }

    func configureSnapshotParameters(with assetCollection: [PHAsset]) {
        assetIdentifiers = assetCollection.map(\.localIdentifier)
        snapshotIdentifier = "\(assetIdentifiers.hashValue)_\(assetIdentifiers.count)"
    }

    func calculateSegmentQuantity() -> Int {
        guard !assetIdentifiers.isEmpty else { return 0 }
        return (assetIdentifiers.count + chunkSize - 1) / chunkSize
    }

    func materializeSegmentAtIndex(index: Int) -> PRChunkSnapshot? {
        guard index >= 0, index < calculateSegmentQuantity() else { return nil }
        let fileLocation = fileManager.locateSegmentFile(index)

        if let fileData = try? Data(contentsOf: fileLocation),
           let decodedSnapshot = try? JSONDecoder().decode(PRChunkSnapshot.self, from: fileData) {
            return decodedSnapshot
        }

        let startIndex = index * chunkSize
        let endIndex = min(startIndex + chunkSize, assetIdentifiers.count)
        let segmentIdentifiers = Array(assetIdentifiers[startIndex..<endIndex])

        let segmentAssets = PHAsset.fetchAssets(withLocalIdentifiers: segmentIdentifiers, options: nil).toArray()
        var creationDateMap: [String:Int64] = [:]
        var fileSizeMap: [String:Int64] = [:]
        creationDateMap.reserveCapacity(segmentAssets.count)
        fileSizeMap.reserveCapacity(segmentAssets.count)

        for assetItem in segmentAssets {
            creationDateMap[assetItem.localIdentifier] = Int64((assetItem.creationDate ?? .distantPast).timeIntervalSince1970)
            fileSizeMap[assetItem.localIdentifier] = computeResourceVolume(assetItem)
        }

        var assetEntries = [PRPhotoAssetModel](); assetEntries.reserveCapacity(segmentIdentifiers.count)
        for identifier in segmentIdentifiers {
            assetEntries.append(.init(id: identifier, bytes: fileSizeMap[identifier] ?? 0, date: creationDateMap[identifier] ?? 0))
        }

        let chunkSnapshot = PRChunkSnapshot(index: index, entries: assetEntries)
        if let encodedData = try? JSONEncoder().encode(chunkSnapshot) {
            try? encodedData.write(to: fileLocation, options: .atomic)
        }
        return chunkSnapshot
    }
}
