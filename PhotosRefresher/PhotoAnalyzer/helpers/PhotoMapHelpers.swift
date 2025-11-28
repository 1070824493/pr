//
//  PRPhotoMapHelpers.swift
//  Cleanup
//

//

import Foundation
import Photos
import UIKit
import AVFoundation
import Accelerate
import CoreGraphics


final class PHashCache {
    static let shared = PHashCache()
    private let cache = NSCache<NSString, NSNumber>()
    private init() {
        cache.countLimit = 20_000        // 按库规模调整
        cache.totalCostLimit = 0          // 不按 cost 驱逐就保持 0
    }
    @inline(__always) func get(_ id: String) -> UInt64? {
        cache.object(forKey: id as NSString)?.uint64Value
    }
    @inline(__always) func set(_ id: String, value: UInt64) {
        cache.setObject(NSNumber(value: value), forKey: id as NSString)
    }
}

// MARK: - 这里主要给各个鉴别模块用
func thumbnail(for asset: PHAsset,
               manager: PHImageManager = PHImageManager.default(),
               options: PHImageRequestOptions,
               target: CGSize,
               contentMode: PHImageContentMode = .aspectFit) -> UIImage? {
    var out: UIImage?
    autoreleasepool {
        manager.requestImage(for: asset,
                             targetSize: target,
                             contentMode: contentMode,
                             options: options) { img, _ in
            out = img
        }
    }
    return out
}
func videoKeyframeImage(for asset: PHAsset, target: CGSize) -> UIImage? {
    let sema = DispatchSemaphore(value: 0)
    var avAsset: AVAsset?
    let vOpts = PHVideoRequestOptions()
    vOpts.version = .current; vOpts.deliveryMode = .fastFormat
    PHImageManager.default().requestAVAsset(forVideo: asset, options: vOpts) { a, _, _ in
        avAsset = a; sema.signal()
    }
    _ = sema.wait(timeout: .now() + .seconds(2))
    guard let avAsset else { return nil }
    let gen = AVAssetImageGenerator(asset: avAsset)
    gen.appliesPreferredTrackTransform = true
    gen.maximumSize = target
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    let duration = CMTimeGetSeconds(avAsset.duration)
    let probes = [max(0, duration*0.5), max(0, duration*0.25), max(0, duration*0.75), 0.0]
    for t in probes {
        let time = CMTime(seconds: t, preferredTimescale: 600)
        if let cg = try? gen.copyCGImage(at: time, actualTime: nil) { return UIImage(cgImage: cg) }
    }
    return nil
}

// MARK: - Hashes & Sizes
func computeHashes(
    assets: [PHAsset],
    target: CGSize,                         // 建议 64×64
    options: PHImageRequestOptions          // 建议 isSynchronous = true / fastFormat / fast
) -> (p: [String: UInt64], d: [String: UInt64], wh: [String: (Int, Int)]) {

    var pOut: [String: UInt64] = [:]
    var dOut: [String: UInt64] = [:]
    var whOut: [String: (Int, Int)] = [:]
    pOut.reserveCapacity(assets.count)
    dOut.reserveCapacity(assets.count)
    whOut.reserveCapacity(assets.count)

    let mgr = PHImageManager.default()

    for a in assets {
        autoreleasepool {
            let id = a.localIdentifier
            whOut[id] = (a.pixelWidth, a.pixelHeight)

            // 1) 命中缓存：直接得 pHash，且通常无需解码图像
            if let cached = PHashCache.shared.get(id) {
                pOut[id] = cached
                // 仍可能需要 dHash；下面按需要再取图
            }

            var img: UIImage? = nil
            // 2) 只有在确实需要 pHash 或 dHash 时才解码图像/取关键帧
            if pOut[id] == nil || dOut[id] == nil {
                if a.mediaType == .video {
                    img = safeVideoKeyframeImage(for: a, target: target)
                } else {
                    img = thumbnail(for: a, manager: mgr, options: options, target: target)
                }
            }

            // 3) 计算 pHash
            if pOut[id] == nil, let ui = img, let ph = pHash64(from: ui) {
                pOut[id] = ph
                PHashCache.shared.set(id, value: ph)   // 写缓存（线程安全）
            }

            // 4) 计算 dHash（只在拿到图像时才算）
            if dOut[id] == nil, let ui = img, let dh = dHash64(from: ui) {
                dOut[id] = dh
            }
            // img 出作用域后由 autoreleasepool 回收
        }
    }
    return (pOut, dOut, whOut)
}

// MARK: - 视频关键帧取图（加一层 autoreleasepool 更稳）
@inline(__always)
private func safeVideoKeyframeImage(for asset: PHAsset, target: CGSize) -> UIImage? {
    return autoreleasepool(invoking: { () -> UIImage? in
        videoKeyframeImage(for: asset, target: target)
    })
}


func dHash64(from image: UIImage) -> UInt64? {
    guard let cg = image.cgImage else { return nil }
    let W = 9, H = 8
    let grayCS = CGColorSpaceCreateDeviceGray()
    guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W, space: grayCS, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    ctx.interpolationQuality = .low
    ctx.clear(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    guard let data = ctx.data else { return nil }
    let p = data.bindMemory(to: UInt8.self, capacity: W*H)

    var hash: UInt64 = 0
    var bit: UInt64 = 1 << 63
    for y in 0..<H {
        for x in 0..<(W-1) {
            let a = p[y*W + x], b = p[y*W + x + 1]
            if a > b { hash |= bit }
            bit >>= 1
        }
    }
    return hash
}

func pHash64(from image: UIImage) -> UInt64? {
    // 仅缓存 DCT 实例（线程安全且不捕获外部变量）
    struct DCTPool {
        static let side = 32
        static let row = vDSP.DCT(count: side, transformType: .II)
        static let col = vDSP.DCT(count: side, transformType: .II)
    }

    let side = DCTPool.side
    guard let cg = image.cgImage else { return nil }

    // 灰度 32x32
    let grayCS = CGColorSpaceCreateDeviceGray()
    guard let ctx = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: side,
        space: grayCS, bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .low
    let rect = AVMakeRect(
        aspectRatio: CGSize(width: cg.width, height: cg.height),
        insideRect: CGRect(x: 0, y: 0, width: side, height: side)
    )
    ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))
    ctx.draw(cg, in: rect)

    guard let data = ctx.data else { return nil }
    let u8 = data.bindMemory(to: UInt8.self, capacity: side * side)

    // 临时缓冲（放函数内，避免并发写冲突）
    var buf  = [Float](repeating: 0, count: side * side)
    var tmp  = [Float](repeating: 0, count: side * side)
    var dct2 = [Float](repeating: 0, count: side * side)

    // U8 -> Float
    for i in 0..<(side * side) { buf[i] = Float(u8[i]) }

    // 行 DCT（复用 row/out 缓冲，避免循环内频繁分配）
    var row  = [Float](repeating: 0, count: side)
    var out  = [Float](repeating: 0, count: side)
    for r in 0..<side {
        let off = r * side
        // 拷贝一行到 row
        for c in 0..<side { row[c] = buf[off + c] }
        DCTPool.row?.transform(row, result: &out)
        for c in 0..<side { tmp[off + c] = out[c] }
    }

    // 列 DCT
    var col = [Float](repeating: 0, count: side)
    for c in 0..<side {
        for r in 0..<side { col[r] = tmp[r * side + c] }
        DCTPool.col?.transform(col, result: &out)
        for r in 0..<side { dct2[r * side + c] = out[r] }
    }

    // 取左上 8x8 系数并阈值化
    let n = 8
    var coeffs = [Float](repeating: 0, count: n * n)
    var k = 0
    for r in 0..<n {
        for c in 0..<n {
            coeffs[k] = dct2[r * side + c]
            k += 1
        }
    }

    // 中位数阈值
    let median: Float = {
        var arr = coeffs
        arr.sort()
        let mid = arr.count / 2
        return arr.count % 2 == 0 ? 0.5 * (arr[mid - 1] + arr[mid]) : arr[mid]
    }()

    var hash: UInt64 = 0
    for (i, v) in coeffs.enumerated() {
        if v > median { hash |= (1 << UInt64(63 - i)) }
    }
    return hash
}


func laplacianFocusScore(from image: UIImage) -> Float? {
    guard let cg = image.cgImage else { return nil }
    let w = 128, h = 128
    let grayCS = CGColorSpaceCreateDeviceGray()
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: grayCS, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    ctx.interpolationQuality = .low
    let rect = AVMakeRect(aspectRatio: CGSize(width: cg.width, height: cg.height), insideRect: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(cg, in: rect)
    guard let data = ctx.data else { return nil }
    let p = data.bindMemory(to: UInt8.self, capacity: w*h)
    var g = [Float](repeating: 0, count: w*h)
    for i in 0..<(w*h) { g[i] = Float(p[i]) / 255.0 }

    let k: [Float] = [1, -2, 1, -2, 4, -2, 1, -2, 1]
    var lap = [Float](repeating: 0, count: w*h)
    for y in 1..<(h-1) {
        for x in 1..<(w-1) {
            var s: Float = 0
            s += g[(y-1)*w + (x-1)]*k[0]
            s += g[(y-1)*w + x]*k[1]
            s += g[(y-1)*w + (x + 1)]*k[2]
            s += g[y*w + (x-1)]*k[3]
            s += g[y*w + x]*k[4]
            s += g[y*w + (x + 1)]*k[5]
            s += g[(y + 1)*w + (x-1)]*k[6]
            s += g[(y + 1)*w + x]*k[7]
            s += g[(y + 1)*w + (x + 1)]*k[8]
            lap[y*w + x] = s
        }
    }

    let n = vDSP_Length(w*h)
    var mean: Float = 0
    vDSP_meanv(lap, 1, &mean, n)
    var squares = [Float](repeating: 0, count: w*h)
    vDSP_vsq(lap, 1, &squares, 1, n)
    var squareMean: Float = 0
    vDSP_meanv(squares, 1, &squareMean, n)
    let variance = squareMean - mean*mean
    return variance
}

public enum PRLog {
    public static var enabled: Bool = true
    @inline(__always)
    public static func d(_ tag: String, _ msg: @autoclosure () -> String,
                         file: String = #fileID, line: Int = #line) {
        guard enabled else { return }
        let ts = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - _cuLogStart)
        print("CU[\(ts)s] [\(tag)] \(msg())  <\(file):\(line)>")
    }
}
private let _cuLogStart = CFAbsoluteTimeGetCurrent()
