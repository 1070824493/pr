//
//  VideoView.swift

//
//  Created by zyb on 2025/9/11.
//

import SwiftUI
import AVKit

struct VideoView: UIViewRepresentable {
    
    let url: URL
    var progressInterval: Double = 0.25
    var onProgress: ((Double) -> Void)?
    var onCompletion: (() -> Void)?
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerView()
        view.backgroundColor = .clear
        view.setupPlayer(url: url, context: context)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新视图布局
        if let playerView = uiView as? PlayerView {
            playerView.playerLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onProgress: onProgress, onCompletion: onCompletion)
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        // 清理资源
        if let playerView = uiView as? PlayerView, let player = playerView.player {
            player.pause()
            if let timeObserver = coordinator.timeObserver {
                player.removeTimeObserver(timeObserver)
            }
        }
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    class PlayerView: UIView {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        
        func setupPlayer(url: URL, context: Context) {
            // 创建播放器
            player = AVPlayer(url: url)
            
            // 创建播放器图层
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.videoGravity = .resizeAspect
            playerLayer?.backgroundColor = UIColor.clear.cgColor
            
            if let playerLayer = playerLayer {
                layer.addSublayer(playerLayer)
            }
            
            // 设置进度观察
            let interval = CMTime(seconds: context.coordinator.progressInterval,
                                 preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            context.coordinator.timeObserver = player?.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { time in
                guard let duration = self.player?.currentItem?.duration.seconds, duration > 0 else { return }
                let progress = time.seconds / duration
                context.coordinator.onProgress?(progress)
            }
            
            // 设置播放完成观察
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(context.coordinator.playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem
            )
            
            // 开始播放
            player?.play()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }
    }
    
    class Coordinator: NSObject {
        var timeObserver: Any?
        var onProgress: ((Double) -> Void)?
        var onCompletion: (() -> Void)?
        let progressInterval: Double
        
        init(onProgress: ((Double) -> Void)?, onCompletion: (() -> Void)?, progressInterval: Double = 0.25) {
            self.onProgress = onProgress
            self.onCompletion = onCompletion
            self.progressInterval = progressInterval
        }
        
        @objc func playerDidFinishPlaying(note: NSNotification) {
            onCompletion?()
        }
    }
}
