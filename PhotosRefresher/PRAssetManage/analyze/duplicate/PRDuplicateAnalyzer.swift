//
//  PRDuplicateAnalyzer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import CoreGraphics
import UIKit

/// 重复图片分组（严格重复）
/// - 输出: 重复分组的 `localIdentifier` 列表集合
enum PRDuplicateAnalyzer {
    private static let duplicateHammingThreshold = 7
    private static let similarityHammingLimit = 14
    private static let maxGroupSize = 120
    private static let aspectRatioTolerance: CGFloat = 0.15

    static func isolateRedundantClusters(in photoAssets: [PHAsset]) async -> [[String]] {
        struct ImageFingerprint: Hashable { let width: Int32; let height: Int32; let timestamp: Int32 }
        var fingerprintBuckets: [ImageFingerprint: [String]] = [:]
        fingerprintBuckets.reserveCapacity(photoAssets.count / 2)
        var dimensionMap: [String: (Int,Int)] = [:]
        dimensionMap.reserveCapacity(photoAssets.count)

        for assetItem in photoAssets where assetItem.mediaType == .image {
            let timeStamp = Int32((assetItem.creationDate ?? assetItem.modificationDate ?? .distantPast).timeIntervalSince1970)
            let fingerprint = ImageFingerprint(width: Int32(assetItem.pixelWidth), height: Int32(assetItem.pixelHeight), timestamp: timeStamp)
            fingerprintBuckets[fingerprint, default: []].append(assetItem.localIdentifier)
            dimensionMap[assetItem.localIdentifier] = (assetItem.pixelWidth, assetItem.pixelHeight)
        }

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true
        let targetDimensions = CGSize(width: 64, height: 64)

        var duplicateConnections: [(String, String)] = []
        duplicateConnections.reserveCapacity(photoAssets.count)

        func computeBandSegmentHash(_ hashValue: UInt64, bandIndex: Int, bandWidth: Int) -> UInt64 {
            let maskValue: UInt64 = bandWidth == 64 ? ~0 : ((1 << UInt64(bandWidth)) - 1)
            let segmentValue = (hashValue >> UInt64(bandIndex * bandWidth)) & maskValue
            return (UInt64(bandIndex) << 56) | segmentValue
        }

        for (_, identifierGroup) in fingerprintBuckets where identifierGroup.count >= 2 {
            var perceptualHashStore: [String: UInt64] = [:]
            var differenceHashStore: [String: UInt64] = [:]
            perceptualHashStore.reserveCapacity(identifierGroup.count)
            differenceHashStore.reserveCapacity(identifierGroup.count)
            
            for assetIdentifier in identifierGroup {
                autoreleasepool {
                    guard let photoAsset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).toArray().first,
                          let processedImage = produceVisualRepresentation(for: photoAsset, manager: imageManager, options: requestOptions, target: targetDimensions) else { return }
                    
                    if let perceptualHashValue = computePerceptualHash(from: processedImage) {
                        perceptualHashStore[assetIdentifier] = perceptualHashValue
                    }
                    if let differenceHashValue = computeDifferenceHash(from: processedImage) {
                        differenceHashStore[assetIdentifier] = differenceHashValue
                    }
                    if differenceHashStore[assetIdentifier] == nil {
                        differenceHashStore[assetIdentifier] = perceptualHashStore[assetIdentifier]
                    }
                }
            }

            var hashSegmentGroups: [UInt64: [String]] = [:]
            hashSegmentGroups.reserveCapacity(min(identifierGroup.count * 8, 1024))
            
            for assetIdentifier in identifierGroup {
                if let hashValue = perceptualHashStore[assetIdentifier] {
                    for segmentIndex in 0..<8 {
                        hashSegmentGroups[computeBandSegmentHash(hashValue, bandIndex: segmentIndex, bandWidth: 8), default: []].append(assetIdentifier)
                    }
                }
            }

            for (_, segmentIdentifiers) in hashSegmentGroups {
                if segmentIdentifiers.count < 2 || segmentIdentifiers.count > maxGroupSize { continue }
                
                for firstPosition in 0..<(segmentIdentifiers.count - 1) {
                    let firstIdentifier = segmentIdentifiers[firstPosition]
                    guard let firstPerceptualHash = perceptualHashStore[firstIdentifier],
                          let firstDifferenceHash = differenceHashStore[firstIdentifier] else { continue }
                    
                    let firstDimensions = dimensionMap[firstIdentifier]
                    
                    for secondPosition in (firstPosition + 1)..<segmentIdentifiers.count {
                        let secondIdentifier = segmentIdentifiers[secondPosition]
                        guard let secondPerceptualHash = perceptualHashStore[secondIdentifier],
                              let secondDifferenceHash = differenceHashStore[secondIdentifier] else { continue }
                        
                        if !checkDimensionRatioConsistency(firstDimensions, dimensionMap[secondIdentifier], tol: aspectRatioTolerance) {
                            continue
                        }
                        
                        let perceptualDistance = (firstPerceptualHash ^ secondPerceptualHash).nonzeroBitCount
                        if perceptualDistance > similarityHammingLimit { continue }
                        
                        let differenceDistance = (firstDifferenceHash ^ secondDifferenceHash).nonzeroBitCount
                        if perceptualDistance <= duplicateHammingThreshold &&
                           differenceDistance <= (duplicateHammingThreshold + 2) {
                            duplicateConnections.append((firstIdentifier, secondIdentifier))
                        }
                    }
                }
            }
        }

        return consolidateRedundantPairs(duplicateConnections)
    }

    private static func checkDimensionRatioConsistency(_ firstDimensions: (Int, Int)?, _ secondDimensions: (Int, Int)?, tol: CGFloat) -> Bool {
        guard let firstDimensions, let secondDimensions else { return false }
        let firstRatio = CGFloat(firstDimensions.0) / max(1, CGFloat(firstDimensions.1))
        let secondRatio = CGFloat(secondDimensions.0) / max(1, CGFloat(secondDimensions.1))
        return abs(firstRatio - secondRatio) / max(firstRatio, secondRatio) <= tol
    }

    private static func consolidateRedundantPairs(_ connectionPairs: [(String, String)]) -> [[String]] {
        if connectionPairs.isEmpty { return [] }
        
        var identifierIndexMap: [String: Int] = [:]
        func getIndex(_ identifier: String) -> Int {
            if let existingIndex = identifierIndexMap[identifier] { return existingIndex }
            let newIndex = identifierIndexMap.count
            identifierIndexMap[identifier] = newIndex
            return newIndex
        }
        
        var parentArray = [Int]()
        var rankArray = [Int]()
        
        func ensureCapacity(_ size: Int) {
            if size > parentArray.count {
                let additionalElements = size - parentArray.count
                parentArray.append(contentsOf: parentArray.count..<(parentArray.count + additionalElements))
                rankArray.append(contentsOf: Array(repeating: 0, count: additionalElements))
            }
        }
        
        func findRoot(_ index: Int) -> Int {
            parentArray[index] == index ? index : {
                parentArray[index] = findRoot(parentArray[index])
                return parentArray[index]
            }()
        }
        
        func unionElements(_ indexA: Int, _ indexB: Int) {
            var rootA = findRoot(indexA)
            var rootB = findRoot(indexB)
            if rootA == rootB { return }
            if rankArray[rootA] < rankArray[rootB] { swap(&rootA, &rootB) }
            parentArray[rootB] = rootA
            if rankArray[rootA] == rankArray[rootB] { rankArray[rootA] += 1 }
        }
        
        for (identifierA, identifierB) in connectionPairs {
            let indexA = getIndex(identifierA)
            let indexB = getIndex(identifierB)
            ensureCapacity(max(indexA, indexB) + 1)
            unionElements(indexA, indexB)
        }
        
        var resultGroups: [Int: [String]] = [:]
        for (identifier, index) in identifierIndexMap {
            resultGroups[findRoot(index), default: []].append(identifier)
        }
        
        return Array(resultGroups.values).filter { $0.count >= 2 }
    }
}
