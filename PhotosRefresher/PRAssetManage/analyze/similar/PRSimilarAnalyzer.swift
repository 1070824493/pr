//
//  PRSimilarAnalyzer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import CoreGraphics

/// 相似图片分组
/// - 输出: 相似分组的 `localIdentifier` 列表集合
enum PRSimilarAnalyzer {
    private static let perceptualSimilarityLimit = 18
    private static let differenceSimilarityLimit = 20
    private static let bandCount = 8
    private static let segmentWidth = 8
    private static let maximumGroupSize = 120

    static func locateAnalogousAssetClusters(in mediaCollection: [PHAsset]) async -> [[String]] {
        guard !mediaCollection.isEmpty else { return [] }
        let imageRequestConfiguration = PHImageRequestOptions()
        imageRequestConfiguration.isSynchronous = true
        imageRequestConfiguration.deliveryMode = .fastFormat
        imageRequestConfiguration.resizeMode = .fast
        imageRequestConfiguration.isNetworkAccessAllowed = true
        let processingDimensions = CGSize(width: 64, height: 64)
        let (perceptualSignatures, differenceSignatures, dimensionRecords) = synthesizeVisualFingerprints(assets: mediaCollection, target: processingDimensions, options: imageRequestConfiguration)

        let assetIdentifiers = mediaCollection.map(\.localIdentifier)
        var hashSegmentBuckets: [UInt64: [String]] = [:]
        hashSegmentBuckets.reserveCapacity(min(assetIdentifiers.count * bandCount, 200_000))

        @inline(__always) func computeBandSegmentHash(_ hashValue: UInt64, bandPosition: Int, bitWidth: Int) -> UInt64 {
            let bitmask: UInt64 = bitWidth == 64 ? ~0 : ((1 << UInt64(bitWidth)) - 1)
            let segmentValue = (hashValue >> UInt64(bandPosition * bitWidth)) & bitmask
            return (UInt64(bandPosition) << 56) | segmentValue
        }

        for identifier in assetIdentifiers {
            guard let perceptualHash = perceptualSignatures[identifier] else { continue }
            for bandIndex in 0..<bandCount {
                let hashKey = computeBandSegmentHash(perceptualHash, bandPosition: bandIndex, bitWidth: segmentWidth)
                hashSegmentBuckets[hashKey, default: []].append(identifier)
            }
        }

        var unionFindStructure = LinkSet()
        unionFindStructure.reserveCapacity(assetIdentifiers.count)
        for (_, bucketItems) in hashSegmentBuckets {
            if bucketItems.count < 2 || bucketItems.count > maximumGroupSize { continue }
            for firstIndex in 0..<(bucketItems.count - 1) {
                let firstIdentifier = bucketItems[firstIndex]
                guard let firstPerceptualHash = perceptualSignatures[firstIdentifier],
                      let firstDifferenceHash = differenceSignatures[firstIdentifier] else { continue }
                let firstAssetDimensions = dimensionRecords[firstIdentifier]
                for secondIndex in (firstIndex + 1)..<bucketItems.count {
                    let secondIdentifier = bucketItems[secondIndex]
                    guard let secondPerceptualHash = perceptualSignatures[secondIdentifier],
                          let secondDifferenceHash = differenceSignatures[secondIdentifier] else { continue }
                    if !checkDimensionRatioConsistency(firstAssetDimensions, dimensionRecords[secondIdentifier], tol: 0.15) { continue }
                    if (firstPerceptualHash ^ secondPerceptualHash).nonzeroBitCount > perceptualSimilarityLimit { continue }
                    if (firstDifferenceHash ^ secondDifferenceHash).nonzeroBitCount > differenceSimilarityLimit { continue }
                    unionFindStructure.mergeSets(firstIdentifier, secondIdentifier)
                }
            }
        }
        return unionFindStructure.extractDisjointSets().filter { $0.count >= 2 }
    }

    private static func checkDimensionRatioConsistency(_ firstDimensions: (Int,Int)?, _ secondDimensions: (Int,Int)?, tol: CGFloat) -> Bool {
        guard let firstDimensions, let secondDimensions else { return false }
        let firstAspectRatio = CGFloat(firstDimensions.0) / max(1, CGFloat(firstDimensions.1))
        let secondAspectRatio = CGFloat(secondDimensions.0) / max(1, CGFloat(secondDimensions.1))
        return abs(firstAspectRatio - secondAspectRatio) / max(firstAspectRatio, secondAspectRatio) <= tol
    }

    private struct LinkSet {
        private var parentRelations: [String: String] = [:]
        private var rankValues: [String: Int] = [:]
        mutating func reserveCapacity(_ capacity: Int) {
            parentRelations.reserveCapacity(capacity)
            rankValues.reserveCapacity(capacity)
        }
        private mutating func registerNode(_ node: String) {
            if parentRelations[node] == nil {
                parentRelations[node] = node
                rankValues[node] = 0
            }
        }
        mutating func locateRoot(_ node: String) -> String {
            registerNode(node)
            let parentNode = parentRelations[node]!
            if parentNode == node { return node }
            let rootNode = locateRoot(parentNode)
            parentRelations[node] = rootNode
            return rootNode
        }
        mutating func mergeSets(_ firstNode: String, _ secondNode: String) {
            let firstRoot = locateRoot(firstNode)
            let secondRoot = locateRoot(secondNode)
            if firstRoot == secondRoot { return }
            let firstRank = rankValues[firstRoot] ?? 0
            let secondRank = rankValues[secondRoot] ?? 0
            if firstRank < secondRank {
                parentRelations[firstRoot] = secondRoot
            } else if firstRank > secondRank {
                parentRelations[secondRoot] = firstRoot
            } else {
                parentRelations[secondRoot] = firstRoot
                rankValues[firstRoot] = firstRank + 1
            }
        }
        func extractDisjointSets() -> [[String]] {
            var clusterMapping: [String: [String]] = [:]
            for (node, _) in parentRelations {
                var currentNode = node
                var rootNode = parentRelations[currentNode]!
                while rootNode != currentNode {
                    currentNode = rootNode
                    rootNode = parentRelations[currentNode]!
                }
                clusterMapping[rootNode, default: []].append(node)
            }
            return Array(clusterMapping.values)
        }
    }
}
