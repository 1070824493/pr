//
//  ImageUtils.swift
//

import Foundation
import UIKit

class ImageUtils {
    
    static func compressImage(image: UIImage, compressionQuality: CGFloat = 1.0) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }
    
    static func cropAndCompressImage(image: UIImage, toRect rect: CGRect, compressionQuality: CGFloat = 1.0) -> Data? {
        let rectForCrop = CGRect(
            x: max(0, rect.origin.x),
            y: max(0, rect.origin.y),
            width: min(image.size.width, rect.width),
            height: min(image.size.height, rect.height)
        )
        
        guard let cgImage = image.cgImage else {
            return nil
        }
        let scaleRect = CGRect(x: rectForCrop.origin.x * image.scale,
                               y: rectForCrop.origin.y * image.scale,
                               width: rectForCrop.size.width * image.scale,
                               height: rectForCrop.size.height * image.scale)
        
        guard let croppedCGImage = cgImage.cropping(to: scaleRect) else {
            return nil
        }
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        return compressImage(image: croppedImage, compressionQuality: compressionQuality)
    }
    
    static func cropImageToScreen(image: UIImage) -> UIImage? {
        // 获取屏幕尺寸
        let screenSize = UIScreen.main.bounds.size
        
        let imageSize = image.size
        
        // 计算裁切区域的尺寸
        let cropWidth = min(screenSize.width, imageSize.width)
        let cropHeight = min(screenSize.height, imageSize.height)

        // 计算裁切区域的起始点，使裁切后的图像居中
        let xOrigin = (imageSize.width - cropWidth) / 2
        let yOrigin = (imageSize.height - cropHeight) / 2
        
        let cropRect = CGRect(x: xOrigin, y: yOrigin, width: cropWidth, height: cropHeight)
        
        // 使用 UIGraphicsImageRenderer 绘制裁剪图像
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropWidth, height: cropHeight))
        let croppedImage = renderer.image { _ in
            image.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
        
        return croppedImage
    }

    static func cropImageForScreenAspect(image: UIImage, targetSize: CGSize) -> UIImage? {
        // 原图尺寸
        let imageSize = image.size
        
        // 计算缩放比例：选用较大的比例，以满足填充的需求（和 scaledToFill 一样）
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scaleFactor = max(widthRatio, heightRatio)

        // 按照比例缩放之后的图像尺寸
        let scaledImageSize = CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor)
        
        // 计算绘制的起始点，使其居中对齐
        let xOrigin = (targetSize.width - scaledImageSize.width) / 2
        let yOrigin = (targetSize.height - scaledImageSize.height) / 2
        
        // 开始裁剪图像
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let croppedImage = renderer.image { _ in
            image.draw(in: CGRect(x: xOrigin, y: yOrigin, width: scaledImageSize.width, height: scaledImageSize.height))
        }
        
        return croppedImage
    }

    static func saveImageToSandbox(_ image: UIImage, nameWithSuffix: String) {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("Failed to convert UIImage to Data")
            return
        }
        
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagePath = documentDirectory.appendingPathComponent(nameWithSuffix)
        
        do {
            try imageData.write(to: imagePath)
            print("Image saved successfully at path: \(imagePath)")
        } catch {
            print("Error saving image: \(error)")
        }
    }
    
}
