//
//  PRTextAnalyzer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Photos
import Vision
import CoreGraphics
import CoreImage

/// 文字图片识别
/// - 策略: 先 160px 粗检 (VNDetectTextRectangles) 命中后再 512px 精检 (VNRecognizeText)
/// - 输出: 含文字的图片 `localIdentifier` 列表
enum PRTextAnalyzer {
    static func detectGlyphBearingEntities(in mediaAssets: [PHAsset]) async -> [String] {
        var textContainingIdentifiers: [String] = []
        textContainingIdentifiers.reserveCapacity(mediaAssets.count / 4)

        let imageManager = PHImageManager.default()
        let lowResOptions = PHImageRequestOptions()
        lowResOptions.isSynchronous = true
        lowResOptions.deliveryMode = .fastFormat
        lowResOptions.resizeMode = .fast
        lowResOptions.isNetworkAccessAllowed = false
        
        let highResOptions = PHImageRequestOptions()
        highResOptions.isSynchronous = true
        highResOptions.deliveryMode = .fastFormat
        highResOptions.resizeMode = .fast
        highResOptions.isNetworkAccessAllowed = true

        for mediaItem in mediaAssets where mediaItem.mediaType == .image {
            autoreleasepool {
                guard let lowResolutionImage = produceVisualRepresentation(for: mediaItem, manager: imageManager, options: lowResOptions, target: .init(width: 160, height: 160))?.cgImage else { return }
                if !performInitialTextDetection(lowResolutionImage) { return }
                guard let highResolutionImage = produceVisualRepresentation(for: mediaItem, manager: imageManager, options: highResOptions, target: .init(width: 512, height: 512))?.cgImage else { return }
                if performDetailedTextAnalysis(highResolutionImage) {
                    textContainingIdentifiers.append(mediaItem.localIdentifier)
                }
            }
        }
        return textContainingIdentifiers
    }

    private static func performInitialTextDetection(_ imageData: CGImage) -> Bool {
        let textDetectionRequest = VNDetectTextRectanglesRequest()
        textDetectionRequest.reportCharacterBoxes = false
        let visionHandler = VNImageRequestHandler(cgImage: imageData, options: [:])
        try? visionHandler.perform([textDetectionRequest])
        let detectedRegions = (textDetectionRequest.results as? [VNTextObservation]) ?? []
        return detectedRegions.count >= 1
    }

    private static func performDetailedTextAnalysis(_ imageData: CGImage) -> Bool {
        let textRecognitionRequest = VNRecognizeTextRequest()
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = false
        let recognitionHandler = VNImageRequestHandler(cgImage: imageData, options: [:])
        try? recognitionHandler.perform([textRecognitionRequest])
        let recognitionResults = (textRecognitionRequest.results ?? [])
        let characterCount = recognitionResults.reduce(0) {
            $0 + ($1.topCandidates(1).first?.string.count ?? 0)
        }
        let boundingBoxArea = recognitionResults.reduce(0.0) {
            accumulatedArea, observation in
            accumulatedArea + Double(observation.boundingBox.width * observation.boundingBox.height)
        }
        return characterCount >= 6 || boundingBoxArea >= 0.03
    }
}
