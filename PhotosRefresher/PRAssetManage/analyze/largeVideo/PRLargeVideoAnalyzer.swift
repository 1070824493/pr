//
//  PRLargeVideoAnalyzer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos

/// 大视频分析器
/// - 输入: `PHAsset` 列表
/// - 输出: 达到字节阈值的视频 `localIdentifier` 列表
enum PRLargeVideoAnalyzer {
    static func detectVoluminousVideoEntities(in mediaAssets: [PHAsset], thresholdBytes: Int64) async -> [String] {
        var oversizedVideoIdentifiers: [String] = []
        oversizedVideoIdentifiers.reserveCapacity(mediaAssets.count / 4)
        for mediaItem in mediaAssets where mediaItem.mediaType == .video {
            let resourceSize = computeResourceVolume(mediaItem)
            if resourceSize >= thresholdBytes {
                oversizedVideoIdentifiers.append(mediaItem.localIdentifier)
            }
        }
        return oversizedVideoIdentifiers
    }
}
