//
//  PRPHAsset+Utils.swift

//

//

import Foundation
import Photos
import UIKit

/// 计算资源字节大小（聚合多个资源项）
/// - 参数: `PHAsset`
/// - 返回: 字节数（`Int64`）
func calculateAssetSizeBytes(_ asset: PHAsset) -> Int64 {

    let resources = PHAssetResource.assetResources(for: asset)
        var sum: Int64 = 0
        for res in resources {
            if let n = res.value(forKey: "fileSize") as? NSNumber {
                sum += n.int64Value
            }
        }
        return sum
}

extension PHFetchResult where ObjectType == PHAsset {
    /// 将 `PHFetchResult<PHAsset>` 转为数组
    func toArray() -> [PHAsset] {
        var arr: [PHAsset] = []; arr.reserveCapacity(count)
        enumerateObjects { a,_,_ in arr.append(a) }
        return arr
    }
}

/// 通过 `localIdentifier` 获取单个 `PHAsset`
func retrievePHAsset(by identifier: String) -> PHAsset? {
    let assets = retrievePHAssets(by: [identifier])
    return assets.first
}

/// 通过一组 `localIdentifier` 获取 `PHAsset` 列表（自动过滤空串与去重）
func retrievePHAssets(by identifiers: [String]) -> [PHAsset] {
    guard !identifiers.isEmpty else {
        print("❌ Identifiers array is empty")
        return []
    }
    
    let fetchOptions = PHFetchOptions()
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: fetchOptions)
    var fetched: [PHAsset] = []
    fetched.reserveCapacity(fetchResult.count)
    var dict: [String: PHAsset] = [:]
    fetchResult.enumerateObjects { asset, _, _ in
        dict[asset.localIdentifier] = asset
        fetched.append(asset)
    }
    if fetched.count < identifiers.count {
        print("⚠️ Found \(fetched.count) out of \(identifiers.count) requested assets")
        let missingIdentifiers = identifiers.filter { dict[$0] == nil }
        if !missingIdentifiers.isEmpty { print("📋 Missing identifiers: \(missingIdentifiers)") }
    } else {
        print("✅ Successfully found all \(fetched.count) assets")
    }
    return identifiers.compactMap { dict[$0] }
}
