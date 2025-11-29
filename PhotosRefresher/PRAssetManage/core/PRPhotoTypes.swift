//
//  PRPhotoTypes.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos

public enum PRPhotoCategory: String, Hashable, Codable, Identifiable {
    public var id: String {
        rawValue
    }
    case blurryphoto, duplicatephoto, similarphoto, screenshot
    case largevideo, allvideo
    case livePhoto, textphoto
    case similarvideo
    case selfiephoto, backphoto
}

public enum PRPhotoPipelineState: Equatable {
    case noPermission, requesting, loading, idle, error(String)
}

public struct PRPhotoAssetModel: Codable, Hashable {
    public var assetIdentifier: String
    public var storageSize: Int64
    public var creationTimestamp: Int64
    public var underlyingAsset: PHAsset?

    public init(id: String, bytes: Int64, date: Int64, asset: PHAsset? = nil) {
        self.assetIdentifier = id
        self.storageSize = bytes
        self.creationTimestamp = date
        self.underlyingAsset = asset
    }

    private enum CodingKeys: String, CodingKey { case photoIdentifier, photoBytes, photoDate }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assetIdentifier = try container.decode(String.self, forKey: .photoIdentifier)
        storageSize = try container.decode(Int64.self, forKey: .photoBytes)
        creationTimestamp  = try container.decode(Int64.self, forKey: .photoDate)
        underlyingAsset = nil
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assetIdentifier, forKey: .photoIdentifier)
        try container.encode(storageSize,      forKey: .photoBytes)
        try container.encode(creationTimestamp,       forKey: .photoDate)
    }
}

public struct PRPhotoAssetsMap: Codable {
    public var category: PRPhotoCategory
    public var assets: [PRPhotoAssetModel] = []
    public var totalBytes: Int64 = 0

    public var doubleAssetIDs: [[String]] = []
    public var doubleAssets: [[PRPhotoAssetModel]] = []

    public var assetIDs: [String] { assets.map(\.assetIdentifier) }

    public init(_ c: PRPhotoCategory) { self.category = c }

    private enum CodingKeys: String, CodingKey {
        case category, assets, totalBytes, doubleAssetIDs, doubleAssets
    }
}

