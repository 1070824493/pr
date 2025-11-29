//
//  PRBlurryAnalyzer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import CoreGraphics
import CoreImage
import UIKit

/// 模糊图片检测
/// - 策略: 亮度方差排除纯色/低对比 → 轻量"拉普拉斯近似"方差与自适应阈值
/// - 输出: 模糊图片 `localIdentifier` 列表
enum PRBlurryAnalyzer {
    struct Configuration {
        var blurDetectionThreshold: Double = 2.0
        var uniformImageVarianceLimit: Double = 90.0
        var processingDimensions: CGSize = .init(width: 256, height: 256)
    }

    static func scanForLowResolutionEntities(in imageAssets: [PHAsset], params: Configuration = .init()) async -> [String] {
        var blurryIdentifiers: [String] = []
        blurryIdentifiers.reserveCapacity(imageAssets.count / 4)
        let imageManager = PHImageManager.default()
        let requestConfiguration = PHImageRequestOptions()
        requestConfiguration.isSynchronous = true
        requestConfiguration.deliveryMode = .fastFormat
        requestConfiguration.resizeMode = .fast
        requestConfiguration.isNetworkAccessAllowed = true
        
        for currentAsset in imageAssets where currentAsset.mediaType == .image {
            autoreleasepool {
                if assessImageClarity(currentAsset,
                                    imageManager: imageManager,
                                    requestConfig: requestConfiguration,
                                    dimension: params.processingDimensions,
                                    threshold: params.blurDetectionThreshold,
                                    uniformityLimit: params.uniformImageVarianceLimit) {
                    blurryIdentifiers.append(currentAsset.localIdentifier)
                }
            }
        }
        return blurryIdentifiers
    }

    private static func assessImageClarity(_ photoAsset: PHAsset,
                                         imageManager: PHImageManager,
                                         requestConfig: PHImageRequestOptions,
                                         dimension: CGSize,
                                         threshold: Double,
                                         uniformityLimit: Double) -> Bool {
        guard let imageReference = produceVisualRepresentation(for: photoAsset,
                                                          manager: imageManager,
                                                          options: requestConfig,
                                                          target: dimension)?.cgImage else {
            return false
        }
        
        if calculateLuminanceVariation(imageReference) < uniformityLimit {
            return false
        }
        
        let clarityScore = computeImageSharpnessMetric(imageReference)
        let adaptiveThreshold = calculateAdaptiveClarityThreshold(imageReference, baseThreshold: threshold)
        return clarityScore < adaptiveThreshold
    }

    private static func produceVisualRepresentation(for asset: PHAsset,
                                               manager: PHImageManager,
                                               options: PHImageRequestOptions,
                                               target: CGSize) -> UIImage? {
        var resultImage: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        manager.requestImage(for: asset,
                           targetSize: target,
                           contentMode: .aspectFill,
                           options: options) { image, _ in
            resultImage = image
            semaphore.signal()
        }
        
        semaphore.wait()
        return resultImage
    }

    private static func computeImageSharpnessMetric(_ image: CGImage) -> Double {
        guard let pixelData = image.dataProvider?.data as Data? else { return 0 }
        var gradientSum: Double = 0
        var sampleCounter = 0
        
        pixelData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            let pixelBytes = bufferPointer.bindMemory(to: UInt8.self)
            for index in stride(from: 0, to: pixelBytes.count - 8, by: 8) {
                gradientSum += Double(abs(Int(pixelBytes[index]) - Int(pixelBytes[index + 4])))
                sampleCounter += 1
            }
        }
        return gradientSum / Double(max(1, sampleCounter))
    }

    private static func calculateAdaptiveClarityThreshold(_ image: CGImage, baseThreshold: Double) -> Double {
        let luminanceVariance = calculateLuminanceVariation(image)
        let scalingFactor = min(1.0, max(0.0, luminanceVariance / 60.0))
        return baseThreshold * (0.9 + 0.2 * scalingFactor)
    }

    private static func calculateLuminanceVariation(_ image: CGImage) -> Double {
        guard let pixelData = image.dataProvider?.data as Data? else { return 0 }
        let samplingInterval = max(1, (image.width * image.height) / 4096)
        var runningAverage: Double = 0
        var varianceAccumulator: Double = 0
        var measurementCount: Double = 0
        
        pixelData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            let pixelBytes = bufferPointer.bindMemory(to: UInt8.self)
            for position in stride(from: 0, to: image.width * image.height, by: samplingInterval) {
                let byteOffset = position * 4
                if byteOffset + 2 >= pixelBytes.count { break }
                let blue = Double(pixelBytes[byteOffset])
                let green = Double(pixelBytes[byteOffset + 1])
                let red = Double(pixelBytes[byteOffset + 2])
                let luminanceValue = 0.114 * blue + 0.587 * green + 0.299 * red
                measurementCount += 1
                let difference = luminanceValue - runningAverage
                runningAverage += difference / measurementCount
                varianceAccumulator += difference * (luminanceValue - runningAverage)
            }
        }
        return varianceAccumulator / max(1, measurementCount - 1)
    }
}
