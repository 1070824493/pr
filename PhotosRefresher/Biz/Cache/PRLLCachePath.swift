//
//  LLCachePath.swift
//
//  Created by R on 2025/4/9.
//

import Foundation
import UIKit

// 沙盒 Documents 目录
let docPathUrl = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first
// 沙盒 Library/Caches 目录
let cachePathUrl = FileManager.default.urls(for:.cachesDirectory, in: .userDomainMask).first

let LLCachePathCompatible = "LLCachePathCompatible"

enum AppCachePath: String {
    // FE 资源解压
    case feSource = "FeSource"

    /// 完成沙盒路径
    var fullPathUrl: URL? {
        var pathUrl = docPathUrl
        
        pathUrl = pathUrl?.appendingPathComponent(self.rawValue)
        // 检查目录是否存在
        if let path = pathUrl?.path,
           !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                print("目录创建成功")
            } catch {
                print("创建目录失败：\(error)")
            }
        }
        return pathUrl
    }
    
    func clear() {
        let fileManager = FileManager.default
        
        guard let fullPathUrl, fileManager.fileExists(atPath: fullPathUrl.path()) else {
            print("⚠️ 路径不存在: \(String(describing: fullPathUrl?.path()))")
            return
        }

        do {
            try fileManager.removeItem(atPath: fullPathUrl.path())
            print("✅ 文件夹已删除: \(String(describing: fullPathUrl.path()))")

        } catch {
            print("❌ 删除失败: \(error)")
        }
    }
}

extension AppCachePath {
    
    func shortPath(_ name: String) -> String {
        return self.rawValue.appending("/\(name)")
    }
    
    func save(img: UIImage, name: String? = nil, callBack: ((Bool, String?) -> Void)? = nil) {
        var fileName = name
        if fileName == nil {
            fileName = "\(Date().timeIntervalSince1970)".md5Value + ".png"
        }
        if let data = img.pngData() {
            save(data: data, name: fileName, callBack: callBack)
        } else {
            callBack?(false, nil)
        }
    }
    
    func save(data: Data, name: String? = nil, callBack: ((Bool, String?) -> Void)? = nil) {
        var fileName = name
        if fileName == nil {
            fileName = "\(Date().timeIntervalSince1970)".md5Value
        }
        if let fName = fileName,
           let fileUrl = self.fullPathUrl?.appendingPathComponent(fName) {
            do {
                try data.write(to: fileUrl)
                callBack?(true, self.shortPath(fName))
            } catch {
                callBack?(false, nil)
            }
        }
    }
    static func fullPathUrl(from shortPath: String) -> URL? {
        if let shortUrl = URL(string: shortPath),
           let cache = AppCachePath(rawValue: shortUrl.deletingLastPathComponent().path) {
            let fileName = shortUrl.lastPathComponent
            if let fileUrl = cache.fullPathUrl?.appendingPathComponent(fileName) {
                return fileUrl
            }
        }
        return nil
    }
    
    static func image(from shortPath: String) -> UIImage? {
        if let shortUrl = URL(string: shortPath),
           let cache = AppCachePath(rawValue: shortUrl.deletingLastPathComponent().path) {
            let fileName = shortUrl.lastPathComponent
            if let fileUrl = cache.fullPathUrl?.appendingPathComponent(fileName) {
                do {
                    let imageData = try Data(contentsOf: fileUrl)
                    return UIImage(data: imageData)
                } catch {
                    return nil
                }
            }
        }
        return nil
    }
    
    static func data(from shortPath: String) -> Data? {
        if let shortUrl = URL(string: shortPath),
           let cache = AppCachePath(rawValue: shortUrl.deletingLastPathComponent().path) {
            let fileName = shortUrl.lastPathComponent
            if let fileUrl = cache.fullPathUrl?.appendingPathComponent(fileName) {
                do {
                    let data = try Data(contentsOf: fileUrl)
                    return data
                } catch {
                    return nil
                }
            }
        }
        return nil
    }
}
