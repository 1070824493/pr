//
//  PRDiskSpaceManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation

struct PRDiskSpace: Sendable {
    let totalCapacity: Int64 // 总容量（字节）
    let freeCapacity: Int64 // 可用容量（字节）
    let importantUsageCapacity: Int64? // 系统为"重要任务"可腾出的容量（含可清理空间）
    let opportunisticUsageCapacity: Int64? // 机会性可用
    var utilizedCapacity: Int64 { totalCapacity - freeCapacity } // 已用 = 总 - 可用
}

func assessStorageMetrics() -> PRDiskSpace? {
    let rootDirectory = URL(fileURLWithPath: "/")
    do {
        let resourceKeys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]
        let resourceValues = try rootDirectory.resourceValues(forKeys: resourceKeys)

        if let totalSize = resourceValues.volumeTotalCapacity,
           let availableSize = resourceValues.volumeAvailableCapacity
        {
            return PRDiskSpace(
                totalCapacity: Int64(totalSize),
                freeCapacity: Int64(availableSize),
                importantUsageCapacity: resourceValues.volumeAvailableCapacityForImportantUsage.map { Int64($0) },
                opportunisticUsageCapacity: resourceValues.volumeAvailableCapacityForOpportunisticUsage.map { Int64($0) }
            )
        }
    } catch {}

    // 兜底：老 API（极少用到）
    do {
        let fileSystemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        if let totalSize = (fileSystemAttributes[.systemSize] as? NSNumber)?.int64Value,
           let availableSize = (fileSystemAttributes[.systemFreeSize] as? NSNumber)?.int64Value
        {
            return PRDiskSpace(
                totalCapacity: totalSize,
                freeCapacity: availableSize,
                importantUsageCapacity: nil,
                opportunisticUsageCapacity: nil
            )
        }
    } catch {}
    return nil
}
