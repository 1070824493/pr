//
//  PRSlideCacheManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import Foundation
import Photos

final class PRSlideCacheManager {
    static let shared = PRSlideCacheManager()
    private let key = "photosrefresher.slide.viewed.ids.v1"
    private init() {}

    private struct Store: Codable {
        let map: [String: [String]]
    }

    private func load() -> [String: [String]] {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Store.self, from: data) { return s.map }
        return [:]
    }

    private func save(_ dict: [String: [String]]) {
        if let data = try? JSONEncoder().encode(Store(map: dict)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func viewedIDs(for category: PRPhotoCategory) -> Set<String> {
        let dict = load()
        return Set(dict[category.rawValue] ?? [])
    }

    func markViewed(category: PRPhotoCategory, ids: [String]) {
        guard !ids.isEmpty else { return }
        var dict = load()
        var arr = dict[category.rawValue] ?? []
        var set = Set(arr)
        for id in ids where set.insert(id).inserted { arr.append(id) }
        dict[category.rawValue] = arr
        save(dict)
    }
    
    /// 从数组中获取指定个数未标记的元素
    /// - Parameters:
    ///   - limit: 个数
    ///   - category: 分组
    ///   - sourceIDs: 全集
    func unviewedFirst(limit: Int, category: PRPhotoCategory, sourceIDs: [String]) -> [String] {
        let seen = viewedIDs(for: category)
        var result: [String] = []
        result.reserveCapacity(limit)
        for id in sourceIDs where !seen.contains(id) {
            result.append(id)
            if result.count >= limit { break }
        }
        return result
    }
    
    func cleanAll() {
        UserDefaults.standard.set(nil, forKey: key)
    }
}

extension Notification.Name {

    static let slideSessionDidAdvance = Notification.Name("photosrefresher.slide.session.didAdvance")
}
