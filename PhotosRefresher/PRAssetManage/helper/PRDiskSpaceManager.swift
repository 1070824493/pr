//
//  PRDiskSpaceManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation

struct PRDiskSpace: Sendable {
    let total: Int64 // 总容量（字节）
    let available: Int64 // 可用容量（字节）
    let importantAvailable: Int64? // 系统为“重要任务”可腾出的容量（含可清理空间）
    let opportunisticAvailable: Int64? // 机会性可用
    var used: Int64 { total - available } // 已用 = 总 - 可用
}

func assessStorageMetrics() -> PRDiskSpace? {
    let root = URL(fileURLWithPath: "/")
    do {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]
        let vals = try root.resourceValues(forKeys: keys)

        if let total = vals.volumeTotalCapacity,
           let avail = vals.volumeAvailableCapacity
        {
            return PRDiskSpace(
                total: Int64(total),
                available: Int64(avail),
                importantAvailable: vals.volumeAvailableCapacityForImportantUsage.map { Int64($0) },
                opportunisticAvailable: vals.volumeAvailableCapacityForOpportunisticUsage.map { Int64($0) }
            )
        }
    } catch {}

    // 兜底：老 API（极少用到）
    do {
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        if let total = (attrs[.systemSize] as? NSNumber)?.int64Value,
           let avail = (attrs[.systemFreeSize] as? NSNumber)?.int64Value
        {
            return PRDiskSpace(total: total, available: avail, importantAvailable: nil, opportunisticAvailable: nil)
        }
    } catch {}
    return nil
}

