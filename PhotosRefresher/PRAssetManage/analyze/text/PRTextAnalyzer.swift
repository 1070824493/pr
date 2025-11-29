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
    static func detectGlyphBearingEntities(in assets: [PHAsset]) async -> [String] {
        var hits: [String] = []
        hits.reserveCapacity(assets.count / 4)

        let manager = PHImageManager.default()
        let optLow = PHImageRequestOptions(); optLow.isSynchronous = true; optLow.deliveryMode = .fastFormat; optLow.resizeMode = .fast; optLow.isNetworkAccessAllowed = false
        let optHi  = PHImageRequestOptions(); optHi.isSynchronous  = true; optHi.deliveryMode  = .fastFormat; optHi.resizeMode  = .fast;  optHi.isNetworkAccessAllowed  = true

        for a in assets where a.mediaType == .image {
            autoreleasepool {
                guard let low = produceVisualRepresentation(for: a, manager: manager, options: optLow, target: .init(width: 160, height: 160))?.cgImage else { return }
                if !performCoarseTextDetection(low) { return }
                guard let hi = produceVisualRepresentation(for: a, manager: manager, options: optHi, target: .init(width: 512, height: 512))?.cgImage else { return }
                if performFineTextRecognition(hi) { hits.append(a.localIdentifier) }
            }
        }
        return hits
    }

    private static func performCoarseTextDetection(_ cg: CGImage) -> Bool {
        let req = VNDetectTextRectanglesRequest(); req.reportCharacterBoxes = false
        let h = VNImageRequestHandler(cgImage: cg, options: [:])
        try? h.perform([req])
        let rects = (req.results as? [VNTextObservation]) ?? []
        return rects.count >= 1
    }

    private static func performFineTextRecognition(_ cg: CGImage) -> Bool {
        let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate; req.usesLanguageCorrection = false
        let h = VNImageRequestHandler(cgImage: cg, options: [:])
        try? h.perform([req])
        let obs = (req.results ?? [])
        let chars = obs.reduce(0) { $0 + ($1.topCandidates(1).first?.string.count ?? 0) }
        let area = obs.reduce(0.0) { s, o in s + Double(o.boundingBox.width * o.boundingBox.height) }
        return chars >= 6 || area >= 0.03
    }
}

