//
//  TrashReviewAlertView.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/20.
//

import SwiftUI
import Photos

public class TrashReviewViewModel: ObservableObject {
    @Published var assets: [PHAsset]
    @Published var selectedIDs: Set<String>
    var onConfirm: (([PHAsset]) -> Void)?
    var onSkip: (() -> Void)?
    var onDismiss: (() -> Void)?
    init(assets: [PHAsset], onConfirm: (([PHAsset]) -> Void)? = nil, onSkip: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.assets = assets
        self.selectedIDs = Set(assets.map { $0.localIdentifier })
        self.onConfirm = onConfirm
        self.onSkip = onSkip
        self.onDismiss = onDismiss
    }
    
    var selectedAssets: [PHAsset] {
        assets.filter { selectedIDs.contains($0.localIdentifier) }
    }
    
    var isSelectedAll: Bool {
        selectedIDs.count == assets.count && !selectedIDs.isEmpty
    }
    
    func toggleAll() {
        if isSelectedAll {
            selectedIDs.removeAll()
        }else{
            self.selectedIDs = Set(assets.map { $0.localIdentifier })
        }
    }
    
    func toggle(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
}

struct TrashReviewAlertView: View {
    @ObservedObject var model: TrashReviewViewModel
    private let provider = PRAssetThumbnailProvider()
    private let gridSpacing: CGFloat = 6
    var body: some View {
        
        VStack(spacing: 16) {
            if model.assets.isEmpty {
                //垃圾桶为空视图
                Text("Review Complete")
                    .font(.semibold24)
                    .foregroundColor(Color.white)
                    .padding(.top, 20)
                
                Text("One more set?")
                    .font(.regular16)
                    .foregroundColor(Color.white.opacity(0.5))
                
                Spacer()
                    .frame(height: 420)
                
                Button(action: { model.onSkip?() }) {
                    Text("One More Set")
                        .font(.regular14)
                        .foregroundColor(Color.white)
                        .frame(height: fitScale(44))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .background(Color.hexColor(0x186F6F).opacity(0.1))
                        .cornerRadius(fitScale(12))
                        .overlay(
                            RoundedRectangle(cornerRadius: fitScale(12))
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .padding(.bottom, fitScale(24))
            }else {
                
                //不为空, 选择删除
                Text("Dustbin")
                    .font(.semibold24)
                    .foregroundColor(Color.white)
                    .padding(.top, 20)
                
                HStack {
                    Button(action: model.toggleAll) {
                        Text(model.isSelectedAll ? "Deselect all" : "Select all")
                            .font(.semibold16)
                            .foregroundColor(Color.white)
                    }
                    Spacer()
                }
                
                
                //相册展示
                ScrollView(.vertical) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3), spacing: gridSpacing) {
                        ForEach(model.assets, id: \.localIdentifier) { a in
                            let w = (kScreenWidth - fitScale(15)*2 - gridSpacing * 2 - 12.0 * 2) / 3.0
                            ZStack(alignment: .topTrailing) {
                                Button(action: { model.toggle(a) }) {
                                    provider.constructVisualElement(for: a, targetSize: CGSize(width: w, height: w))
                                        .frame(width: w, height: w)
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(model.selectedIDs.contains(a.localIdentifier) ? "icon_photo_selected" : "icon_photo_normal")
                                                .resizable()
                                                .frame(width: 24, height: 24)
                                                .padding(10)
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            if a.mediaType == .video {
                                                Text(formatDuration(a.duration))
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.black.opacity(0.35))
                                                    .cornerRadius(6)
                                                    .padding(6)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(width: w, height: w)
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(height: 420)
                
                //取消和确认
                HStack(spacing: 10) {
                    Button(action: { model.onDismiss?() }) {
                        Text("Cancel")
                            .font(.regular14)
                            .foregroundColor(Color.white)
                            .frame(height: fitScale(44))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .background(Color.hexColor(0x186F6F).opacity(0.1))
                            .cornerRadius(fitScale(12))
                            .overlay(
                                RoundedRectangle(cornerRadius: fitScale(12))
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    Button(action: {
                        if !model.selectedAssets.isEmpty {
                            model.onConfirm?(model.selectedAssets)
                        }
                    }) {
                        Text("Confirm")
                            .font(.system(size: fitScale(16), weight: .semibold))
                            .foregroundColor(Color.white)
                            .frame(height: fitScale(44))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .background(Color.hexColor(0xFF5329).opacity(model.selectedAssets.isEmpty ? 0.5 : 1))
                    .cornerRadius(fitScale(12))
                }
                .padding(.bottom, fitScale(24))
            }
            
        }
        .cornerRadius(24)
        .padding(.horizontal, 15)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        }
        
        
        
        
    }
    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return "\(m):\(String(format: "%02d", r))"
    }
}
