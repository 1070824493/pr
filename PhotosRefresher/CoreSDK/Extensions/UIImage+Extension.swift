//
//  UIImage+Extension.swift
//  OverseasSwiftExtensions
//

import UIKit

public extension UIImage {
    
    func toBase64(compressionQuality: CGFloat = 1.0, withPrefix: Bool = false, toJpeg: Bool = true) -> String? {
        var imageData: Data?
        var mimeType = "image/jpeg"
        
        if toJpeg {
            if let jpegData = self.jpegData(compressionQuality: compressionQuality) {
                imageData = jpegData
            }
        } else {
            if let pngData = self.pngData() {
                imageData = pngData
                mimeType = "image/png"
            }
        }
        
        guard let imageData = imageData else {
            return nil
        }
        
        var base64 = imageData.base64EncodedString()
        if withPrefix {
            base64 = "data:\(mimeType);base64,\(base64)"
        }
        return base64
    }
    
    func toBase64(compressionQuality: CGFloat = 1.0, withPrefix: Bool = false, toJpeg: Bool = true) async -> String? {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let base64String: String? = self.toBase64(compressionQuality: compressionQuality, withPrefix: withPrefix, toJpeg: toJpeg)
                continuation.resume(returning: base64String)
            }
        }
    }
    
}
