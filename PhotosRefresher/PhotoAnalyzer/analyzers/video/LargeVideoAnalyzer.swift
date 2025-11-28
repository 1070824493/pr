import Foundation
import Photos

/// 大视频分析器
/// - 输入: `PHAsset` 列表
/// - 输出: 达到字节阈值的视频 `localIdentifier` 列表
enum LargeVideoAnalyzer {
    static func analyzeIDs(in assets: [PHAsset], thresholdBytes: Int64) async -> [String] {
        var ids: [String] = []
        ids.reserveCapacity(assets.count / 4)
        for a in assets where a.mediaType == .video {
            let sz = assetSizeBytes(a)
            if sz >= thresholdBytes { ids.append(a.localIdentifier) }
        }
        return ids
    }
}