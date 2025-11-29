//
//  PRGroupMerge.swift

//

//

import Foundation

enum PRGroupMerge {
    static func mergeAssetGroups(existing: [[String]], adding: [[String]]) -> [[String]] {
        var groups = existing.map { Set($0) }
        for raw in adding where raw.count >= 2 {
            var s = Set(raw)
            var toRemove: [Int] = []
            for (i, g) in groups.enumerated() where !g.isDisjoint(with: s) {
                s.formUnion(g)
                toRemove.append(i)
            }
            for i in toRemove.sorted(by: >) { groups.remove(at: i) }
            groups.append(s)
        }
        return groups.map(Array.init)
    }
}
