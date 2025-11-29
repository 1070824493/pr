import Foundation
import Photos
import CoreGraphics

/// 相似图片分组
/// - 输出: 相似分组的 `localIdentifier` 列表集合
enum PRSimilarAnalyzer {
    private static let pThreshold = 18
    private static let dThreshold = 20
    private static let bands = 8
    private static let segW = 8
    private static let maxBucket = 120

    static func findSimilarAssetGroups(in assets: [PHAsset]) async -> [[String]] {
        guard !assets.isEmpty else { return [] }
        let opts = PHImageRequestOptions(); opts.isSynchronous = true; opts.deliveryMode = .fastFormat; opts.resizeMode = .fast; opts.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: 64, height: 64)
        let (sigP, sigD, dims) = generateImageHashes(assets: assets, target: targetSize, options: opts)

        let ids = assets.map(\.localIdentifier)
        var buckets: [UInt64: [String]] = [:]
        buckets.reserveCapacity(min(ids.count * bands, 200_000))

        @inline(__always) func bandKey(_ hash: UInt64, bandIndex: Int, width: Int) -> UInt64 {
            let mask: UInt64 = width == 64 ? ~0 : ((1 << UInt64(width)) - 1)
            let part = (hash >> UInt64(bandIndex * width)) & mask
            return (UInt64(bandIndex) << 56) | part
        }

        for id in ids {
            guard let h = sigP[id] else { continue }
            for b in 0..<bands {
                let k = bandKey(h, bandIndex: b, width: segW)
                buckets[k, default: []].append(id)
            }
        }

        var uf = LinkSet(); uf.reserveCapacity(ids.count)
        for (_, bid) in buckets {
            if bid.count < 2 || bid.count > maxBucket { continue }
            for i in 0..<(bid.count - 1) {
                let id1 = bid[i]
                guard let p1 = sigP[id1], let d1 = sigD[id1] else { continue }
                let wh1 = dims[id1]
                for j in (i + 1)..<bid.count {
                    let id2 = bid[j]
                    guard let p2 = sigP[id2], let d2 = sigD[id2] else { continue }
                    if !isAspectRatioSimilar(wh1, dims[id2], tol: 0.15) { continue }
                    if (p1 ^ p2).nonzeroBitCount > pThreshold { continue }
                    if (d1 ^ d2).nonzeroBitCount > dThreshold { continue }
                    uf.union(id1, id2)
                }
            }
        }
        return uf.groups().filter { $0.count >= 2 }
    }

    private static func isAspectRatioSimilar(_ a: (Int,Int)?, _ b: (Int,Int)?, tol: CGFloat) -> Bool {
        guard let a, let b else { return false }
        let ra = CGFloat(a.0) / max(1, CGFloat(a.1))
        let rb = CGFloat(b.0) / max(1, CGFloat(b.1))
        return abs(ra - rb) / max(ra, rb) <= tol
    }

    private struct LinkSet {
        private var parent: [String: String] = [:]
        private var rank: [String: Int] = [:]
        mutating func reserveCapacity(_ n: Int) { parent.reserveCapacity(n); rank.reserveCapacity(n) }
        private mutating func add(_ x: String) { if parent[x] == nil { parent[x] = x; rank[x] = 0 } }
        mutating func find(_ x: String) -> String { add(x); let px = parent[x]!; if px == x { return x }; let root = find(px); parent[x] = root; return root }
        mutating func union(_ a: String, _ b: String) { let ra = find(a), rb = find(b); if ra == rb { return }; let raRank = rank[ra] ?? 0; let rbRank = rank[rb] ?? 0; if raRank < rbRank { parent[ra] = rb } else if raRank > rbRank { parent[rb] = ra } else { parent[rb] = ra; rank[ra] = raRank + 1 } }
        func groups() -> [[String]] { var mp: [String: [String]] = [:]; for (k, _) in parent { var cur = k; var root = parent[cur]!; while root != cur { cur = root; root = parent[cur]! }; mp[root, default: []].append(k) }; return Array(mp.values) }
    }
}
