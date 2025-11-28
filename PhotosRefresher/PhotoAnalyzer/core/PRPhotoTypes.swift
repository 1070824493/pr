//
//  PRPhotoTypes.swift

//

//

import Foundation
import Photos

public enum PhotoCategory: String, Hashable, Codable, Identifiable {
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

public struct PhotoAssetModel: Codable, Hashable {
    public var photoIdentifier: String
    public var photoBytes: Int64
    public var photoDate: Int64
    public var photoAsset: PHAsset?

    public init(id: String, bytes: Int64, date: Int64, asset: PHAsset? = nil) {
        self.photoIdentifier = id
        self.photoBytes = bytes
        self.photoDate = date
        self.photoAsset = asset
    }

    private enum CodingKeys: String, CodingKey { case photoIdentifier, photoBytes, photoDate }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        photoIdentifier = try c.decode(String.self, forKey: .photoIdentifier)
        photoBytes = try c.decode(Int64.self, forKey: .photoBytes)
        photoDate  = try c.decode(Int64.self, forKey: .photoDate)
        photoAsset = nil
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(photoIdentifier, forKey: .photoIdentifier)
        try c.encode(photoBytes,      forKey: .photoBytes)
        try c.encode(photoDate,       forKey: .photoDate)
    }
}

public struct PhotoAssetsMap: Codable {
    public var category: PhotoCategory
    public var assets: [PhotoAssetModel] = []
    public var totalBytes: Int64 = 0

    public var doubleAssetIDs: [[String]] = []
    public var doubleAssets: [[PhotoAssetModel]] = []

    public var assetIDs: [String] { assets.map(\.photoIdentifier) }

    public init(_ c: PhotoCategory) { self.category = c }

    private enum CodingKeys: String, CodingKey {
        case category, assets, totalBytes, doubleAssetIDs, doubleAssets
    }
}
