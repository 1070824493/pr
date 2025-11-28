//
//  SystemShareView.swift

//
//  Created by zyb on 2025/8/25.
//

import SwiftUI
import UIKit
import LinkPresentation
import AVFoundation

struct ShareImageActivityView: UIViewControllerRepresentable {
    let items: [UIImage]   // 要分享的图片内容
    let files: [URL]     //视频URL
    let completion: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)?
    
    init(images: [UIImage], files: [URL] = [], completion: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)? = nil) {

        self.items = images
        self.files = files
        self.completion = completion
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        
        var newItems: [Any] = []    //需要展示给系统的所有文件
        let fileThumbs = files.compactMap({makeVideoThumbnail(url: $0)})    //所有视频的缩略图
        
        //图片和视频缩略图合并
        if let thumb = makeGridThumbnail(images: items + fileThumbs, size: CGSize(width: 300, height: 300)) {
            //PreviewItemSource这个只是为了展示处理缩略图和第一张图片
            newItems = [PreviewItemSource(thumbnail: thumb, images: items, files: files)]
           
            var allItems: [Any] = items + files
            if allItems.first != nil {
                allItems.removeFirst()
            }
            
            newItems.append(contentsOf: allItems)
        }
        
        let controller = UIActivityViewController(activityItems: newItems, applicationActivities: nil)
        controller.completionWithItemsHandler = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}

class PreviewItemSource: NSObject, UIActivityItemSource {
    let thumbnail: UIImage
    let images: [UIImage]
    let files: [URL]
    
    init(thumbnail: UIImage, images: [UIImage], files: [URL]) {
        self.thumbnail = thumbnail
        self.images = images
        self.files = files
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return thumbnail
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return images.first ?? files.first
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        if images.count + files.count > 1 {
            metadata.title = "share \(images.count + files.count) medias"
        }else{
            metadata.title = "share \(images.count + files.count) media"
        }
        metadata.imageProvider = NSItemProvider(object: thumbnail)
        return metadata
    }
}

func makeVideoThumbnail(url: URL, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
    let asset = AVAsset(url: url)
    let imgGenerator = AVAssetImageGenerator(asset: asset)
    imgGenerator.appliesPreferredTrackTransform = true
    imgGenerator.maximumSize = size
    do {
        let cgImage = try imgGenerator.copyCGImage(at: .zero, actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        return nil
    }
}

/// 多图合成缩略图（最多9张，九宫格）
func makeGridThumbnail(images: [UIImage], size: CGSize) -> UIImage? {
    guard !images.isEmpty else { return nil }
    
    // 最多9张
    let limited = Array(images.prefix(9))
    
    let gridCount = Int(ceil(sqrt(Double(limited.count)))) // 行列数
    let cellSize = CGSize(width: size.width / CGFloat(gridCount),
                          height: size.height / CGFloat(gridCount))
    
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    
    for (index, img) in limited.enumerated() {
        let row = index / gridCount
        let col = index % gridCount
        let rect = CGRect(x: CGFloat(col) * cellSize.width,
                          y: CGFloat(row) * cellSize.height,
                          width: cellSize.width,
                          height: cellSize.height)
        
        // 按比例缩放填充 cell
        let scale = max(rect.width / img.size.width, rect.height / img.size.height)
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let drawRect = CGRect(x: rect.midX - newSize.width/2,
                              y: rect.midY - newSize.height/2,
                              width: newSize.width,
                              height: newSize.height)
        img.draw(in: drawRect)
    }
    
    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return result
}
