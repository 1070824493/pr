import Foundation
import Photos
import CoreGraphics

/// 重复图片分组（严格重复）
/// - 输出: 重复分组的 `localIdentifier` 列表集合
enum DuplicateAnalyzer {
    private static let hdDup = 7
    private static let hdSimUpper = 14
    private static let maxBucket = 120
    private static let aspectTol: CGFloat = 0.15

    static func analyzeGroupIDs(in assets: [PHAsset]) async -> [[String]] {
        struct FP: Hashable { let w: Int32; let h: Int32; let ts: Int32 }
        var fpBuckets: [FP: [String]] = [:]
        fpBuckets.reserveCapacity(assets.count / 2)
        var dims: [String: (Int,Int)] = [:]
        dims.reserveCapacity(assets.count)

        for a in assets where a.mediaType == .image {
            let ts = Int32((a.creationDate ?? a.modificationDate ?? .distantPast).timeIntervalSince1970)
            let fp = FP(w: Int32(a.pixelWidth), h: Int32(a.pixelHeight), ts: ts)
            fpBuckets[fp, default: []].append(a.localIdentifier)
            dims[a.localIdentifier] = (a.pixelWidth, a.pixelHeight)
        }

        let manager = PHImageManager.default()
        let opts = PHImageRequestOptions(); opts.isSynchronous = true; opts.deliveryMode = .fastFormat; opts.resizeMode = .fast; opts.isNetworkAccessAllowed = true
        let target = CGSize(width: 64, height: 64)

        var pairLinks: [(String, String)] = []
        pairLinks.reserveCapacity(assets.count)

        func bandKey(_ hash: UInt64, bandIndex: Int, bandWidth: Int) -> UInt64 {
            let mask: UInt64 = bandWidth == 64 ? ~0 : ((1 << UInt64(bandWidth)) - 1)
            let part = (hash >> UInt64(bandIndex * bandWidth)) & mask
            return (UInt64(bandIndex) << 56) | part
        }

        for (_, ids) in fpBuckets where ids.count >= 2 {
            var pMap: [String: UInt64] = [:]
            var dMap: [String: UInt64] = [:]
            pMap.reserveCapacity(ids.count)
            dMap.reserveCapacity(ids.count)
            for id in ids {
                autoreleasepool {
                    guard let a = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).toArray().first,
                          let ui = thumbnail(for: a, manager: manager, options: opts, target: target) else { return }
                    if let ph = pHash64(from: ui) { pMap[id] = ph }
                    if let dh = dHash64(from: ui) { dMap[id] = dh }
                    if dMap[id] == nil { dMap[id] = pMap[id] }
                }
            }

            var buckets: [UInt64: [String]] = [:]
            buckets.reserveCapacity(min(ids.count * 8, 1024))
            for id in ids {
                if let h = pMap[id] {
                    for b in 0..<8 { buckets[bandKey(h, bandIndex: b, bandWidth: 8), default: []].append(id) }
                }
            }

            for (_, bid) in buckets {
                if bid.count < 2 || bid.count > maxBucket { continue }
                for i in 0..<(bid.count - 1) {
                    let id1 = bid[i]
                    guard let p1 = pMap[id1], let d1 = dMap[id1] else { continue }
                    let wh1 = dims[id1]
                    for j in (i+1)..<bid.count {
                        let id2 = bid[j]
                        guard let p2 = pMap[id2], let d2 = dMap[id2] else { continue }
                        if !aspectClose(wh1, dims[id2], tol: aspectTol) { continue }
                        let hdp = (p1 ^ p2).nonzeroBitCount
                        if hdp > hdSimUpper { continue }
                        let hdd = (d1 ^ d2).nonzeroBitCount
                        if hdp <= hdDup && hdd <= (hdDup + 2) { pairLinks.append((id1, id2)) }
                    }
                }
            }
        }

        return unifyPairs(pairLinks)
    }

    private static func aspectClose(_ a: (Int, Int)?, _ b: (Int, Int)?, tol: CGFloat) -> Bool {
        guard let a, let b else { return false }
        let ra = CGFloat(a.0) / max(1, CGFloat(a.1))
        let rb = CGFloat(b.0) / max(1, CGFloat(b.1))
        return abs(ra - rb) / max(ra, rb) <= tol
    }

    private static func unifyPairs(_ links: [(String, String)]) -> [[String]] {
        if links.isEmpty { return [] }
        var id2idx: [String: Int] = [:]
        func idx(_ id: String) -> Int { if let i = id2idx[id] { return i }; let i = id2idx.count; id2idx[id] = i; return i }
        var parent = [Int](); var rank = [Int]()
        func ensure(_ n: Int) { if n > parent.count { let add = n - parent.count; parent.append(contentsOf: parent.count..<(parent.count+add)); rank.append(contentsOf: Array(repeating: 0, count: add)) } }
        func find(_ x: Int) -> Int { parent[x] == x ? x : { parent[x] = find(parent[x]); return parent[x] }() }
        func uni(_ a: Int, _ b: Int) { var x = find(a), y = find(b); if x == y { return }; if rank[x] < rank[y] { swap(&x,&y) }; parent[y] = x; if rank[x] == rank[y] { rank[x] += 1 } }
        for (a, b) in links { let ia = idx(a), ib = idx(b); ensure(max(ia, ib) + 1); uni(ia, ib) }
        var buckets: [Int: [String]] = [:]
        for (id, i) in id2idx { buckets[find(i), default: []].append(id) }
        return Array(buckets.values).filter { $0.count >= 2 }
    }
}