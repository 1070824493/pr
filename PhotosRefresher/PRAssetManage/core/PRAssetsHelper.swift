//
//  PRAssetsHelper.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import UIKit
import AVFoundation
import Accelerate
import CoreGraphics

enum PRGroupMerge {
    static func mergeAssetGroups(existingGroups: [[String]], newGroups: [[String]]) -> [[String]] {
        var mergedGroups = existingGroups.map { Set($0) }
        for newGroup in newGroups where newGroup.count >= 2 {
            var combinedSet = Set(newGroup)
            var indicesToRemove: [Int] = []
            for (index, existingSet) in mergedGroups.enumerated() where !existingSet.isDisjoint(with: combinedSet) {
                combinedSet.formUnion(existingSet)
                indicesToRemove.append(index)
            }
            for index in indicesToRemove.sorted(by: >) { mergedGroups.remove(at: index) }
            mergedGroups.append(combinedSet)
        }
        return mergedGroups.map(Array.init)
    }
}

/// 计算资源字节大小（聚合多个资源项）
/// - 参数: `PHAsset`
/// - 返回: 字节数（`Int64`）
func computeResourceVolume(_ mediaAsset: PHAsset) -> Int64 {
    let assetResources = PHAssetResource.assetResources(for: mediaAsset)
    var totalSize: Int64 = 0
    for resourceItem in assetResources {
        if let fileSizeValue = resourceItem.value(forKey: "fileSize") as? NSNumber {
            totalSize += fileSizeValue.int64Value
        }
    }
    return totalSize
}

extension PHFetchResult where ObjectType == PHAsset {
    /// 将 `PHFetchResult<PHAsset>` 转为数组
    func toArray() -> [PHAsset] {
        var assetArray: [PHAsset] = []
        assetArray.reserveCapacity(count)
        enumerateObjects { assetItem, _, _ in assetArray.append(assetItem) }
        return assetArray
    }
}

/// 通过 `localIdentifier` 获取单个 `PHAsset`
func fetchAssetEntity(by assetIdentifier: String) -> PHAsset? {
    let matchingAssets = fetchAssetEntities(by: [assetIdentifier])
    return matchingAssets.first
}

/// 通过一组 `localIdentifier` 获取 `PHAsset` 列表（自动过滤空串与去重）
func fetchAssetEntities(by assetIdentifiers: [String]) -> [PHAsset] {
    guard !assetIdentifiers.isEmpty else {
        print("❌ Identifiers array is empty")
        return []
    }
    
    let fetchConfiguration = PHFetchOptions()
    let fetchResults = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: fetchConfiguration)
    var retrievedAssets: [PHAsset] = []
    retrievedAssets.reserveCapacity(fetchResults.count)
    var identifierToAssetMap: [String: PHAsset] = [:]
    fetchResults.enumerateObjects { assetItem, _, _ in
        identifierToAssetMap[assetItem.localIdentifier] = assetItem
        retrievedAssets.append(assetItem)
    }
    if retrievedAssets.count < assetIdentifiers.count {
        print("⚠️ Found \(retrievedAssets.count) out of \(assetIdentifiers.count) requested assets")
        let missingIdentifiers = assetIdentifiers.filter { identifierToAssetMap[$0] == nil }
        if !missingIdentifiers.isEmpty { print("📋 Missing identifiers: \(missingIdentifiers)") }
    } else {
        print("✅ Successfully found all \(retrievedAssets.count) assets")
    }
    return assetIdentifiers.compactMap { identifierToAssetMap[$0] }
}

extension PRAssetsHelper {

    /// 删除资产（需要 VIP 权限），支持传入现有 `PHAsset` 或 `localIdentifier` 数组
    public func purgeResourcesWithPrivilegeVerification(
        _ assets: [PHAsset],
        assetIDs: [String]? = nil,
        uiState: PRUIState,
        paySource: PaySource = .guided,
        from: String = "",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let assetsToDelete: [PHAsset] = {
            if !assets.isEmpty { return assets }
            if let ids = assetIDs, !ids.isEmpty { return fetchAssetEntities(by: ids) }
            return []
        }()

        guard !assetsToDelete.isEmpty else {
            completion(.success(()))
            return
        }

//        StatisticsManager.log(name: "JHQ_001", params: ["from": from])

        if !PRUserManager.shared.isVip() {
            Task { @MainActor in
                uiState.fullScreenCoverDestination = .subscription(
                    paySource: paySource,
                    onDismiss: { isSuccess in
                        uiState.fullScreenCoverDestination = nil
                        if isSuccess {
                            self.executeResourcePurge(assetsToDelete, from: from, completion: completion)
                        } else {
                            completion(.failure(PRAssetsExecError.requestCancelled))
                        }
                    }
                )
            }
        } else {
            executeResourcePurge(assetsToDelete, from: from, completion: completion)
        }
    }
}

/// 资产工具集合：缩略图加载与批量删除
class PRAssetsHelper {
    
    public static let shared = PRAssetsHelper()
    
    /// 加载高清缩略图（允许 iCloud 下载，屏蔽降质结果）
    func acquireHighFidelityImage(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    ) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let requestConfiguration = PHImageRequestOptions()
            requestConfiguration.isSynchronous = false
            requestConfiguration.deliveryMode = deliveryMode
            requestConfiguration.resizeMode = .fast
            requestConfiguration.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestConfiguration
            ) { imageData, infoDictionary in
                if let errorInfo = infoDictionary?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: errorInfo)
                    return
                }
                
                if let isDegradedFlag = infoDictionary?[PHImageResultIsDegradedKey] as? Bool, isDegradedFlag {
                    return
                }
                
                guard let resultImage = imageData else {
                    continuation.resume(throwing: PRAssetsExecError.imageNotFound)
                    return
                }
                
                continuation.resume(returning: resultImage)
            }
        }
    }
    
    /// 加载快速缩略图（不走网络，首帧快）
    func acquireRapidImage(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let requestConfiguration = PHImageRequestOptions()
            requestConfiguration.isSynchronous = false
            requestConfiguration.deliveryMode = .fastFormat
            requestConfiguration.resizeMode = .fast
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestConfiguration
            ) { imageData, infoDictionary in
                if let errorInfo = infoDictionary?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: errorInfo)
                    return
                }
                
                guard let resultImage = imageData else {
                    continuation.resume(throwing: PRAssetsExecError.imageNotFound)
                    return
                }
                
                continuation.resume(returning: resultImage)
            }
        }
    }
    
    /// 并发加载缩略图（自动聚合结果）
    func acquireCompositeImages(
        for assets: [PHAsset],
        targetSize: CGSize = CGSize(width: 200, height: 200),
        faster: Bool = false
    ) async throws -> [String: UIImage] {
        var imageResults: [String: UIImage] = [:]
        try await withThrowingTaskGroup(of: (String, UIImage).self) { taskGroup in
            for assetItem in assets {
                taskGroup.addTask {
                    var processedImage: UIImage
                    if faster {
                        processedImage = try await self.acquireRapidImage(for: assetItem, targetSize: targetSize)
                    } else {
                        processedImage = try await self.acquireHighFidelityImage(for: assetItem, targetSize: targetSize)
                    }
                    return (assetItem.localIdentifier, processedImage)
                }
            }
            
            for try await (assetIdentifier, imageData) in taskGroup {
                imageResults[assetIdentifier] = imageData
            }
        }
        
        return imageResults
    }
    
    /// 限并发批量加载缩略图（分块）
    func acquireImagesConstrained(
        for assets: [PHAsset],
        targetSize: CGSize = CGSize(width: 200, height: 200),
        maxConcurrentTasks: Int = 4,
        faster: Bool = false
    ) async throws -> [String: UIImage] {
        var imageResults: [String: UIImage] = [:]
        let assetBatches = assets.chunked(into: maxConcurrentTasks)
        
        for batch in assetBatches {
            try await withThrowingTaskGroup(of: (String, UIImage).self) { taskGroup in
                for assetItem in batch {
                    taskGroup.addTask {
                        var processedImage: UIImage
                        if faster {
                            processedImage = try await self.acquireRapidImage(for: assetItem, targetSize: targetSize)
                        } else {
                            processedImage = try await self.acquireHighFidelityImage(for: assetItem, targetSize: targetSize)
                        }
                        return (assetItem.localIdentifier, processedImage)
                    }
                }
                
                for try await (assetIdentifier, imageData) in taskGroup {
                    imageResults[assetIdentifier] = imageData
                }
            }
        }
        
        return imageResults
    }
    
    /// 执行删除（已授权）
    private func executeResourcePurge(_ assetsToDelete: [PHAsset], from: String, completion: @escaping (Result<Void, Error>) -> Void) {
        
        guard !assetsToDelete.isEmpty else {
            completion(.success(()))
            return
        }
        
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            completion(.failure(PRAssetsExecError.authorizationDenied))
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { successStatus, errorInfo in
//            StatisticsManager.log(name: "JHQ_002", params: ["from": from])
            DispatchQueue.main.async {
                if successStatus {
                    PRPhotoMapManager.shared.lastDeleteAssets = assetsToDelete
                    completion(.success(()))
                } else {
                    completion(.failure(errorInfo ?? PRAssetsExecError.unknown))
                }
            }
        }
    }
}

enum PRAssetsExecError: Error, LocalizedError {
    case imageNotFound
    case authorizationDenied
    case requestCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .imageNotFound:
            return "imageNotFound"
        case .authorizationDenied:
            return "authorizationDenied"
        case .requestCancelled:
            return "requestCancelled"
        case .unknown:
            return "unknown"
        }
    }
}

final class PRPHashCache {
    static let shared = PRPHashCache()
    private let storageCache = NSCache<NSString, NSNumber>()
    private init() {
        storageCache.countLimit = 20_000
        storageCache.totalCostLimit = 0
    }
    @inline(__always) func accessFingerprint(_ identifier: String) -> UInt64? {
        storageCache.object(forKey: identifier as NSString)?.uint64Value
    }
    @inline(__always) func depositFingerprint(_ identifier: String, value: UInt64) {
        storageCache.setObject(NSNumber(value: value), forKey: identifier as NSString)
    }
}

// MARK: - 这里主要给各个鉴别模块用
func produceVisualRepresentation(for mediaAsset: PHAsset,
                       manager: PHImageManager = PHImageManager.default(),
                       options: PHImageRequestOptions,
                       target: CGSize,
                       contentMode: PHImageContentMode = .aspectFit) -> UIImage? {
    var outputImage: UIImage?
    autoreleasepool {
        manager.requestImage(for: mediaAsset,
                             targetSize: target,
                             contentMode: contentMode,
                             options: options) { imageData, _ in
            outputImage = imageData
        }
    }
    return outputImage
}

func deriveVideoFrame(for mediaAsset: PHAsset, target: CGSize) -> UIImage? {
    let synchronizationSemaphore = DispatchSemaphore(value: 0)
    var videoAsset: AVAsset?
    let videoOptions = PHVideoRequestOptions()
    videoOptions.version = .current
    videoOptions.deliveryMode = .fastFormat
    PHImageManager.default().requestAVAsset(forVideo: mediaAsset, options: videoOptions) { asset, _, _ in
        videoAsset = asset
        synchronizationSemaphore.signal()
    }
    _ = synchronizationSemaphore.wait(timeout: .now() + .seconds(2))
    guard let videoAsset else { return nil }
    let imageGenerator = AVAssetImageGenerator(asset: videoAsset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.maximumSize = target
    imageGenerator.requestedTimeToleranceBefore = .zero
    imageGenerator.requestedTimeToleranceAfter = .zero
    let videoDuration = CMTimeGetSeconds(videoAsset.duration)
    let sampleTimes = [max(0, videoDuration*0.5), max(0, videoDuration*0.25), max(0, videoDuration*0.75), 0.0]
    for timePoint in sampleTimes {
        let timeStamp = CMTime(seconds: timePoint, preferredTimescale: 600)
        if let frameImage = try? imageGenerator.copyCGImage(at: timeStamp, actualTime: nil) {
            return UIImage(cgImage: frameImage)
        }
    }
    return nil
}

// MARK: - Hashes & Sizes
func synthesizeVisualFingerprints(
    assets: [PHAsset],
    target: CGSize,
    options: PHImageRequestOptions
) -> (p: [String: UInt64], d: [String: UInt64], wh: [String: (Int, Int)]) {
    
    var perceptualHashes: [String: UInt64] = [:]
    var differenceHashes: [String: UInt64] = [:]
    var dimensionsMap: [String: (Int, Int)] = [:]
    perceptualHashes.reserveCapacity(assets.count)
    differenceHashes.reserveCapacity(assets.count)
    dimensionsMap.reserveCapacity(assets.count)
    
    let imageManager = PHImageManager.default()
    
    for assetItem in assets {
        autoreleasepool {
            let assetIdentifier = assetItem.localIdentifier
            dimensionsMap[assetIdentifier] = (assetItem.pixelWidth, assetItem.pixelHeight)
            
            if let cachedHash = PRPHashCache.shared.accessFingerprint(assetIdentifier) {
                perceptualHashes[assetIdentifier] = cachedHash
            }
            
            var processedImage: UIImage? = nil
            if perceptualHashes[assetIdentifier] == nil || differenceHashes[assetIdentifier] == nil {
                if assetItem.mediaType == .video {
                    processedImage = securelyDeriveVideoFrame(for: assetItem, target: target)
                } else {
                    processedImage = produceVisualRepresentation(for: assetItem, manager: imageManager, options: options, target: target)
                }
            }
            
            if perceptualHashes[assetIdentifier] == nil,
               let imageData = processedImage,
               let perceptualHash = computePerceptualHash(from: imageData) {
                perceptualHashes[assetIdentifier] = perceptualHash
                PRPHashCache.shared.depositFingerprint(assetIdentifier, value: perceptualHash)
            }
            
            if differenceHashes[assetIdentifier] == nil,
               let imageData = processedImage,
               let differenceHash = computeDifferenceHash(from: imageData) {
                differenceHashes[assetIdentifier] = differenceHash
            }
        }
    }
    return (perceptualHashes, differenceHashes, dimensionsMap)
}

// MARK: - 视频关键帧取图（加一层 autoreleasepool 更稳）
@inline(__always)
private func securelyDeriveVideoFrame(for mediaAsset: PHAsset, target: CGSize) -> UIImage? {
    return autoreleasepool(invoking: { () -> UIImage? in
        deriveVideoFrame(for: mediaAsset, target: target)
    })
}

func computeDifferenceHash(from imageData: UIImage) -> UInt64? {
    guard let cgImage = imageData.cgImage else { return nil }
    let outputWidth = 9, outputHeight = 8
    let grayColorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: nil,
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bytesPerRow: outputWidth,
        space: grayColorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else { return nil }
    
    context.interpolationQuality = .low
    context.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
    guard let pixelData = context.data else { return nil }
    let pixelBytes = pixelData.bindMemory(to: UInt8.self, capacity: outputWidth * outputHeight)
    
    var hashValue: UInt64 = 0
    var currentBit: UInt64 = 1 << 63
    for row in 0..<outputHeight {
        for column in 0..<(outputWidth - 1) {
            let leftPixel = pixelBytes[row * outputWidth + column]
            let rightPixel = pixelBytes[row * outputWidth + column + 1]
            if leftPixel > rightPixel { hashValue |= currentBit }
            currentBit >>= 1
        }
    }
    return hashValue
}

func computePerceptualHash(from imageData: UIImage) -> UInt64? {
    struct DCTPool {
        static let dimension = 32
        static let rowTransform = vDSP.DCT(count: dimension, transformType: .II)
        static let columnTransform = vDSP.DCT(count: dimension, transformType: .II)
    }
    
    let dimension = DCTPool.dimension
    guard let cgImage = imageData.cgImage else { return nil }
    
    let grayColorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: nil,
        width: dimension,
        height: dimension,
        bitsPerComponent: 8,
        bytesPerRow: dimension,
        space: grayColorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else { return nil }
    
    context.interpolationQuality = .low
    let drawingRect = AVMakeRect(
        aspectRatio: CGSize(width: cgImage.width, height: cgImage.height),
        insideRect: CGRect(x: 0, y: 0, width: dimension, height: dimension)
    )
    context.clear(CGRect(x: 0, y: 0, width: dimension, height: dimension))
    context.draw(cgImage, in: drawingRect)
    
    guard let pixelData = context.data else { return nil }
    let pixelBytes = pixelData.bindMemory(to: UInt8.self, capacity: dimension * dimension)
    
    var floatBuffer = [Float](repeating: 0, count: dimension * dimension)
    var tempBuffer = [Float](repeating: 0, count: dimension * dimension)
    var dctResult = [Float](repeating: 0, count: dimension * dimension)
    
    for index in 0..<(dimension * dimension) {
        floatBuffer[index] = Float(pixelBytes[index])
    }
    
    var rowBuffer = [Float](repeating: 0, count: dimension)
    var outputBuffer = [Float](repeating: 0, count: dimension)
    for row in 0..<dimension {
        let rowOffset = row * dimension
        for column in 0..<dimension {
            rowBuffer[column] = floatBuffer[rowOffset + column]
        }
        DCTPool.rowTransform?.transform(rowBuffer, result: &outputBuffer)
        for column in 0..<dimension {
            tempBuffer[rowOffset + column] = outputBuffer[column]
        }
    }
    
    var columnBuffer = [Float](repeating: 0, count: dimension)
    for column in 0..<dimension {
        for row in 0..<dimension {
            columnBuffer[row] = tempBuffer[row * dimension + column]
        }
        DCTPool.columnTransform?.transform(columnBuffer, result: &outputBuffer)
        for row in 0..<dimension {
            dctResult[row * dimension + column] = outputBuffer[row]
        }
    }
    
    let coefficientSize = 8
    var coefficients = [Float](repeating: 0, count: coefficientSize * coefficientSize)
    var coefficientIndex = 0
    for row in 0..<coefficientSize {
        for column in 0..<coefficientSize {
            coefficients[coefficientIndex] = dctResult[row * dimension + column]
            coefficientIndex += 1
        }
    }
    
    let medianValue: Float = {
        var sortedCoefficients = coefficients
        sortedCoefficients.sort()
        let middleIndex = sortedCoefficients.count / 2
        return sortedCoefficients.count % 2 == 0 ?
            0.5 * (sortedCoefficients[middleIndex - 1] + sortedCoefficients[middleIndex]) :
            sortedCoefficients[middleIndex]
    }()
    
    var finalHash: UInt64 = 0
    for (index, coefficient) in coefficients.enumerated() {
        if coefficient > medianValue {
            finalHash |= (1 << UInt64(63 - index))
        }
    }
    return finalHash
}

func computeLaplacianOperatorScore(from imageData: UIImage) -> Float? {
    guard let cgImage = imageData.cgImage else { return nil }
    let processingWidth = 128, processingHeight = 128
    let grayColorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: nil,
        width: processingWidth,
        height: processingHeight,
        bitsPerComponent: 8,
        bytesPerRow: processingWidth,
        space: grayColorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else { return nil }
    
    context.interpolationQuality = .low
    let drawingRect = AVMakeRect(
        aspectRatio: CGSize(width: cgImage.width, height: cgImage.height),
        insideRect: CGRect(x: 0, y: 0, width: processingWidth, height: processingHeight)
    )
    context.clear(CGRect(x: 0, y: 0, width: processingWidth, height: processingHeight))
    context.draw(cgImage, in: drawingRect)
    
    guard let pixelData = context.data else { return nil }
    let pixelBytes = pixelData.bindMemory(to: UInt8.self, capacity: processingWidth * processingHeight)
    var normalizedValues = [Float](repeating: 0, count: processingWidth * processingHeight)
    for index in 0..<(processingWidth * processingHeight) {
        normalizedValues[index] = Float(pixelBytes[index]) / 255.0
    }
    
    let kernelWeights: [Float] = [1, -2, 1, -2, 4, -2, 1, -2, 1]
    var laplacianResults = [Float](repeating: 0, count: processingWidth * processingHeight)
    for row in 1..<(processingHeight - 1) {
        for column in 1..<(processingWidth - 1) {
            var convolutionSum: Float = 0
            convolutionSum += normalizedValues[(row-1)*processingWidth + (column-1)] * kernelWeights[0]
            convolutionSum += normalizedValues[(row-1)*processingWidth + column] * kernelWeights[1]
            convolutionSum += normalizedValues[(row-1)*processingWidth + (column + 1)] * kernelWeights[2]
            convolutionSum += normalizedValues[row*processingWidth + (column-1)] * kernelWeights[3]
            convolutionSum += normalizedValues[row*processingWidth + column] * kernelWeights[4]
            convolutionSum += normalizedValues[row*processingWidth + (column + 1)] * kernelWeights[5]
            convolutionSum += normalizedValues[(row + 1)*processingWidth + (column-1)] * kernelWeights[6]
            convolutionSum += normalizedValues[(row + 1)*processingWidth + column] * kernelWeights[7]
            convolutionSum += normalizedValues[(row + 1)*processingWidth + (column + 1)] * kernelWeights[8]
            laplacianResults[row*processingWidth + column] = convolutionSum
        }
    }
    
    let elementCount = vDSP_Length(processingWidth * processingHeight)
    var meanValue: Float = 0
    vDSP_meanv(laplacianResults, 1, &meanValue, elementCount)
    var squaredValues = [Float](repeating: 0, count: processingWidth * processingHeight)
    vDSP_vsq(laplacianResults, 1, &squaredValues, 1, elementCount)
    var squaredMean: Float = 0
    vDSP_meanv(squaredValues, 1, &squaredMean, elementCount)
    let varianceValue = squaredMean - meanValue * meanValue
    return varianceValue
}

private let _performanceLogStartTime = CFAbsoluteTimeGetCurrent()
