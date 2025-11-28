//
//  PRPhotoCacheSnapshots.swift

//

//

import Foundation

let kBytesSchemaVersion: Int = 1
let kPersistEveryN: Int = 3

public struct DashboardCell: Codable {
    public var category: PhotoCategory
    public var bytes: Int64
    public var repID: [String]
    public var count: Int

    public init(category: PhotoCategory, bytes: Int64, repID: [String], count: Int) {
        self.category = category
        self.bytes = bytes
        self.repID = repID
        self.count = count
    }
}

public struct DashboardSnapshot: Codable {
    public var cells: [DashboardCell]
    public var totalSize: Int64
    public var updatedAt: Date

    public init(cells: [DashboardCell], totalSize: Int64, updatedAt: Date) {
        self.cells = cells
        self.totalSize = totalSize
        self.updatedAt = updatedAt
    }
}

extension CacheFiles {
    var dashboard: URL { dir.appendingPathComponent("dashboard.json") }
}

struct ChunkSnapshot: Codable {
    let index: Int
    let entries: [PhotoAssetModel]
}

struct ProgressSnapshot: Codable {
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

struct MapsSnapshot: Codable {
    var screenshot: [PhotoAssetModel]; var screenshotBytes: Int64
    var live: [PhotoAssetModel];       var liveBytes: Int64
    var allvideo: [PhotoAssetModel];   var allvideoBytes: Int64

    var selfie: [PhotoAssetModel];     var selfieBytes: Int64
    var back: [PhotoAssetModel];       var backBytes: Int64

    var large: [PhotoAssetModel];      var largeBytes: Int64
    var blurry: [PhotoAssetModel];     var blurryBytes: Int64
    var text: [PhotoAssetModel];       var textBytes: Int64

    var similarGroupIds: [[String]];   var similarGroupModels: [[PhotoAssetModel]];   var similarBytes: Int64
    var duplicateGroupIds: [[String]]; var duplicateGroupModels: [[PhotoAssetModel]]; var duplicateBytes: Int64

    var totalSize: Int64
    var bytesSchemaVersion: Int
    var updatedAt: Date
}

struct CacheFiles {
    let dir: URL
    var progress: URL { dir.appendingPathComponent("progress.json") }
    var maps: URL { dir.appendingPathComponent("maps.json") }
    func chunk(_ i: Int) -> URL { dir.appendingPathComponent("chunk_\(i).json") }
}
