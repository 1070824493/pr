//
//  PRBlurryAnalyzer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import CoreGraphics
import CoreImage

/// 模糊图片检测
/// - 策略: 亮度方差排除纯色/低对比 → 轻量“拉普拉斯近似”方差与自适应阈值
/// - 输出: 模糊图片 `localIdentifier` 列表
enum PRBlurryAnalyzer {
    struct Params {
        var blurThresholdBase: Double = 2.0
        var flatVarYThreshold: Double = 90.0
        var targetSize: CGSize = .init(width: 256, height: 256)
    }

    static func detectBlurryAssetIdentifiers(in assets: [PHAsset], params: Params = .init()) async -> [String] {
        var ids: [String] = []
        ids.reserveCapacity(assets.count / 4)
        let manager = PHImageManager.default()
        let opt = PHImageRequestOptions(); opt.isSynchronous = true; opt.deliveryMode = .fastFormat; opt.resizeMode = .fast; opt.isNetworkAccessAllowed = true
        for a in assets where a.mediaType == .image {
            autoreleasepool {
                if checkIfAssetIsBlurry(a, manager: manager, options: opt, target: params.targetSize, base: params.blurThresholdBase, flatThr: params.flatVarYThreshold) {
                    ids.append(a.localIdentifier)
                }
            }
        }
        return ids
    }

    private static func checkIfAssetIsBlurry(_ asset: PHAsset, manager: PHImageManager, options: PHImageRequestOptions, target: CGSize, base: Double, flatThr: Double) -> Bool {
        guard let cg = generateThumbnail(for: asset, manager: manager, options: options, target: target)?.cgImage else { return false }
        if calculateLumaVariance(cg) < flatThr { return false }
        let lv = calculateLightweightEdgeVariance(cg)
        let thr = computeAdaptiveBlurThreshold(cg, base: base)
        return lv < thr
    }

    private static func calculateLightweightEdgeVariance(_ cg: CGImage) -> Double {
        guard let data = cg.dataProvider?.data as Data? else { return 0 }
        var acc: Double = 0
        var cnt = 0
        data.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
            let bytes = p.bindMemory(to: UInt8.self)
            for i in stride(from: 0, to: bytes.count - 8, by: 8) {
                acc += Double(abs(Int(bytes[i]) - Int(bytes[i + 4])))
                cnt += 1
            }
        }
        return acc / Double(max(1, cnt))
    }

    private static func computeAdaptiveBlurThreshold(_ cg: CGImage, base: Double) -> Double {
        let varY = calculateLumaVariance(cg)
        let k = min(1.0, max(0.0, varY / 60.0))
        return base * (0.9 + 0.2 * k)
    }

    private static func calculateLumaVariance(_ cg: CGImage) -> Double {
        guard let data = cg.dataProvider?.data as Data? else { return 0 }
        let step = max(1, (cg.width * cg.height) / 4096)
        var mean: Double = 0, m2: Double = 0, n: Double = 0
        data.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
            let bytes = p.bindMemory(to: UInt8.self)
            for i in stride(from: 0, to: cg.width * cg.height, by: step) {
                let idx = i * 4
                if idx + 2 >= bytes.count { break }
                let b = Double(bytes[idx]), g = Double(bytes[idx+1]), r = Double(bytes[idx+2])
                let y = 0.114*b + 0.587*g + 0.299*r
                n += 1
                let d = y - mean
                mean += d / n
                m2 += d * (y - mean)
            }
        }
        return m2 / max(1, n - 1)
    }
}
