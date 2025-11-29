//
//  PRSnapshots.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation


let kBytesSchemaVersion: Int = 1
let kPersistEveryN: Int = 3

public struct PRDashboardCell: Codable {
    public var category: PRPhotoCategory
    public var bytes: Int64
    public var repID: [String]
    public var count: Int

    public init(category: PRPhotoCategory, bytes: Int64, repID: [String], count: Int) {
        self.category = category
        self.bytes = bytes
        self.repID = repID
        self.count = count
    }
}

public struct PRDashboardSnapshot: Codable {
    public var cells: [PRDashboardCell]
    public var totalSize: Int64
    public var updatedAt: Date

    public init(cells: [PRDashboardCell], totalSize: Int64, updatedAt: Date) {
        self.cells = cells
        self.totalSize = totalSize
        self.updatedAt = updatedAt
    }
}

extension PRCacheFiles {
    var dashboard: URL { dir.appendingPathComponent("dashboard.json") }
}

struct PRChunkSnapshot: Codable {
    let index: Int
    let entries: [PRPhotoAssetModel]
}

struct PRProgressSnapshot: Codable {
    var snapshotHash: String
    var lastA: Int
    var lastSimilar: Int
    var lastDuplicate: Int
    var lastLarge: Int
    var lastBlurry: Int
    var lastText: Int
    var bytesSchemaVersion: Int
    var updatedAt: Date
}

struct PRMapsSnapshot: Codable {
    var screenshot: [PRPhotoAssetModel]; var screenshotBytes: Int64
    var live: [PRPhotoAssetModel];       var liveBytes: Int64
    var allvideo: [PRPhotoAssetModel];   var allvideoBytes: Int64

    var selfie: [PRPhotoAssetModel];     var selfieBytes: Int64
    var back: [PRPhotoAssetModel];       var backBytes: Int64

    var large: [PRPhotoAssetModel];      var largeBytes: Int64
    var blurry: [PRPhotoAssetModel];     var blurryBytes: Int64
    var text: [PRPhotoAssetModel];       var textBytes: Int64

    var similarGroupIds: [[String]];   var similarGroupModels: [[PRPhotoAssetModel]];   var similarBytes: Int64
    var duplicateGroupIds: [[String]]; var duplicateGroupModels: [[PRPhotoAssetModel]]; var duplicateBytes: Int64

    var totalSize: Int64
    var bytesSchemaVersion: Int
    var updatedAt: Date
}

struct PRCacheFiles {
    let dir: URL
    var progress: URL { dir.appendingPathComponent("progress.json") }
    var maps: URL { dir.appendingPathComponent("maps.json") }
    func locateSegmentFile(_ i: Int) -> URL { dir.appendingPathComponent("chunk_\(i).json") }
}
