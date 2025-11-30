//
//  PRPhotoTypes.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos

public struct PRAssetsInfo: Codable {
    public var type: PRAssetType
    public var assets: [PRAssetsAnalyzeResult] = []
    public var bytes: Int64 = 0

    public var groupAssetLocalIdentifiers: [[String]] = []
    public var groupAssets: [[PRAssetsAnalyzeResult]] = []

    public var localIdentifiers: [String] { assets.map(\.assetIdentifier) }

    public init(_ c: PRAssetType) { self.type = c }

    private enum CodingKeys: String, CodingKey {
        case type, assets, bytes, groupAssetLocalIdentifiers, groupAssets
    }
}

public enum PRAssetType: String, Hashable, Codable, Identifiable {
    public var id: String {
        rawValue
    }
    case selfiephoto, backphoto
    case PhotosBlurry, PhotosDuplicate, PhotosSimilar, PhotosScreenshot
    case PhotosLive, PhotosText
    case VideoLarge, VideoAll
}

public enum PRAssetsPiplineStatus: Equatable {
    case permissionDefined, requesting, loading, idle, error(String)
}

public struct PRAssetsAnalyzeResult: Codable, Hashable {
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
