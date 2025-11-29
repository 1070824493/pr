//
//  PRSnapshots.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation


let kDataFormatVersion: Int = 1
let kSaveInterval: Int = 3

public struct PRDashboardCell: Codable {
    public var classification: PRPhotoCategory
    public var storageUsage: Int64
    public var previewIdentifiers: [String]
    public var elementCount: Int

    public init(category: PRPhotoCategory, bytes: Int64, repID: [String], count: Int) {
        self.classification = category
        self.storageUsage = bytes
        self.previewIdentifiers = repID
        self.elementCount = count
    }
}

public struct PRDashboardSnapshot: Codable {
    public var cellCollectioncellCollection: [PRDashboardCell]
    public var aggregateSize: Int64
    public var modificationDate: Date

    public init(cells: [PRDashboardCell], totalSize: Int64, updatedAt: Date) {
        self.cellCollectioncellCollection = cells
        self.aggregateSize = totalSize
        self.modificationDate = updatedAt
    }
}

extension PRCacheFiles {
    var dashboard: URL { storageDirectory.appendingPathComponent("dashboard.json") }
}

struct PRChunkSnapshot: Codable {
    let index: Int
    let entries: [PRPhotoAssetModel]
}

struct PRProgressSnapshot: Codable {
    var analysisIdentifier: String
    var lastPrimaryPhase: Int
    var lastSimilarityPhase: Int
    var lastDuplicationPhase: Int
    var lastOversizedPhase: Int
    var lastBlurDetectionPhase: Int
    var lastTextDetectionPhase: Int
    var dataFormatVersion: Int
    var analysisTimestamp: Date
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
    let storageDirectory: URL
    var progress: URL { storageDirectory.appendingPathComponent("progress.json") }
    var maps: URL { storageDirectory.appendingPathComponent("maps.json") }
    func locateSegmentFile(_ i: Int) -> URL { storageDirectory.appendingPathComponent("chunk_\(i).json") }
}
