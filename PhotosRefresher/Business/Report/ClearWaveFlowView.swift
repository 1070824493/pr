//
//  ClearWaveFlowView.swift

//
//  Created by yangsonglei on 2025/9/28.
//

import SwiftUI
import AVFoundation
import CoreMotion
import Combine
import Accelerate

// MARK: - 业务状态
enum ClearWaveState: Equatable {
    case guide
    case running
    case done
    case failed(String)

    var canStart: Bool {
        if case .guide = self { return true }
        if case .failed = self { return true }
        return false
    }
}

// MARK: - 面朝下监控（CMMotionManager）
final class FaceDownMonitor: ObservableObject {
    @Published var isFaceDown: Bool = false
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    
    // 添加状态管理
    private var isRunning = false

    func start() {
        guard motion.isDeviceMotionAvailable, !isRunning else { return }
        motion.deviceMotionUpdateInterval = 0.2
        motion.startDeviceMotionUpdates(to: queue) { [weak self] dm, error in
            guard let self = self, error == nil, let g = dm?.gravity else { return }
            // 使用更稳定的判断逻辑，添加滞后防止抖动
            let faceDown = g.z < -0.75
            DispatchQueue.main.async { self.isFaceDown = faceDown }
        }
        isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        isRunning = false
    }
    
    deinit {
        stop()
    }
}

// MARK: - 排水音频内核（AVAudioEngine）
final class WaterEjector {
    enum Segment: Equatable {
        case chirp(ChirpConfig)
        case silence(TimeInterval)
        case file(url: URL, gain: Float = 1.0, start: TimeInterval = 0, duration: TimeInterval? = nil)

        var duration: TimeInterval {
            switch self {
            case .chirp(let c): return c.duration
            case .silence(let d): return d
            case .file(_, _, _, let d): return d ?? 0
            }
        }
    }

    struct ChirpConfig: Equatable {
        var duration: TimeInterval = 3.0
        var startHz: Double = 120
        var endHz: Double = 320
        var amplitude: Float = 0.7
        var fade: TimeInterval = 0.05
    }

    struct Config {
        var sampleRate: Double = 48_000
        var channels: AVAudioChannelCount = 2
        var ioBufferDuration: TimeInterval = 0.005
        var preferSpeaker: Bool = true
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioFormat: AVAudioFormat!

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: AnyCancellable?
    private var startTime: Date?
    private var finishSent = false

    private(set) var isRunning = false

    var onProgress: ((Double) -> Void)?
    var onFinished: ((Bool, String?) -> Void)?

    private var config = Config()
    private var playlist: [Segment] = []
    private var playlistCursor: Int = 0
    private var playlistTotalDuration: TimeInterval = 0
    private var scheduledCompletionHandler = false

    init(config: Config = Config()) {
        self.config = config
        setupAudioEngine()
        observeInterruption()
        observeRouteChange()
    }

    private func setupAudioEngine() {
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: config.sampleRate, channels: config.channels)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
        engine.prepare()
    }

    // MARK: Public API
    func start(segments: [Segment]) {
        guard !isRunning else { return }
        resetFinishFlag()
        
        playlist = segments
        playlistCursor = 0
        scheduledCompletionHandler = false
        playlistTotalDuration = computeTotalDuration(segments: segments)
        
        guard playlistTotalDuration > 0 else {
            finish(success: false, error: "播放列表为空")
            return
        }

        do {
            try configureSession()
            guard isBuiltInSpeakerRoute() else {
                finish(success: false, error: "请断开耳机或蓝牙设备，使用扬声器播放")
                return
            }
            
            if !engine.isRunning {
                try engine.start()
            }
            
            isRunning = true
            player.play()
            startTime = Date()
            scheduleNextIfNeeded()
            tickProgress()
        } catch {
            finish(success: false, error: "音频启动失败: \(error.localizedDescription)")
        }
    }

//    func startLegacy(totalDuration: TimeInterval = 60,
//                     segment: TimeInterval = 3.0,
//                     startHz: Double = 120,
//                     endHz: Double = 320,
//                     rest: TimeInterval = 0.35,
//                     amplitude: Float = 0.7) {
//        var segs: [Segment] = []
//        var elapsed: TimeInterval = 0
//        while elapsed < totalDuration {
//            let d = min(segment, totalDuration - elapsed)
//            segs.append(.chirp(ChirpConfig(duration: d, startHz: startHz, endHz: endHz, amplitude: amplitude)))
//            elapsed += d
//            if elapsed < totalDuration, rest > 0 {
//                let r = min(rest, totalDuration - elapsed)
//                segs.append(.silence(r))
//                elapsed += r
//            }
//        }
//        start(segments: segs)
//    }
    
    func startLegacy(totalDuration: TimeInterval = 60,
                     startHz: Double = 300,
                     endHz: Double = 400,
                     amplitude: Float = 0.7,
                     fade: TimeInterval = 0.00) {
        // 连续播放：从低频扫到高频，再回落到低频；无任何间歇或静音
        let up = Segment.chirp(ChirpConfig(duration: 50,
                                           startHz: startHz, endHz: endHz,
                                           amplitude: amplitude, fade: fade))
        let down = Segment.chirp(ChirpConfig(duration: 10,
                                             startHz: endHz, endHz: 100,
                                             amplitude: amplitude, fade: fade))
        start(segments: [up, down])
    }

    func stop() {
        guard isRunning else { return }
        cleanup()
        finish(success: true, error: nil)
    }

    private func cleanup() {
        progressTimer?.cancel()
        player.stop()
        engine.stop()
        deactivateSession()
        isRunning = false
        scheduledCompletionHandler = false
    }

    deinit {
        cleanup()
    }

    // MARK: - Scheduling
    private func scheduleNextIfNeeded() {
        guard isRunning, playlistCursor < playlist.count else {
            // 所有片段都已调度完成
            if !scheduledCompletionHandler {
                scheduledCompletionHandler = true
                // 添加一个微小延迟确保最后一个buffer播放完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.stop()
                }
            }
            return
        }

        let seg = playlist[playlistCursor]
        playlistCursor += 1

        switch seg {
        case .silence(let d):
            let buf = makeSilenceBuffer(duration: d, format: audioFormat)
            player.scheduleBuffer(buf) { [weak self] in
                DispatchQueue.main.async {
                    self?.scheduleNextIfNeeded()
                }
            }

        case .chirp(let c):
            let buf = makeChirpBuffer(cfg: c, format: audioFormat)
            player.scheduleBuffer(buf) { [weak self] in
                DispatchQueue.main.async {
                    self?.scheduleNextIfNeeded()
                }
            }

        case .file(let url, let gain, let start, let dOpt):
            scheduleFileSegment(url: url, gain: gain, start: start, duration: dOpt)
        }
    }

    private func scheduleFileSegment(url: URL, gain: Float, start: TimeInterval, duration: TimeInterval?) {
        do {
            let file = try AVAudioFile(forReading: url)
            let fileFormat = file.processingFormat
            let totalFileDur = Double(file.length) / fileFormat.sampleRate
            let useDuration = min(duration ?? (totalFileDur - start), max(0, totalFileDur - start))
            
            guard useDuration > 0 else {
                scheduleNextIfNeeded()
                return
            }

            let startFrame = AVAudioFramePosition(start * fileFormat.sampleRate)
            let framesToRead = AVAudioFrameCount(useDuration * fileFormat.sampleRate)
            
            if fileFormat.isEqual(audioFormat) {
                // 格式相同，直接调度
                player.scheduleSegment(file,
                                       startingFrame: startFrame,
                                       frameCount: framesToRead,
                                       at: nil) { [weak self] in
                    DispatchQueue.main.async { self?.scheduleNextIfNeeded() }
                }
            } else {
                // 格式不同，需要转换
                scheduleFileWithConversion(file: file, startFrame: startFrame, framesToRead: framesToRead, gain: gain)
            }
        } catch {
            print("文件读取失败: \(error)")
            scheduleNextIfNeeded()
        }
    }

    private func scheduleFileWithConversion(file: AVAudioFile, startFrame: AVAudioFramePosition, framesToRead: AVAudioFrameCount, gain: Float) {
        do {
            file.framePosition = startFrame
            let tmpBuf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesToRead)!
            try file.read(into: tmpBuf, frameCount: framesToRead)
            
            guard let converter = AVAudioConverter(from: file.processingFormat, to: audioFormat) else {
                throw NSError(domain: "WaterEjector", code: 1, userInfo: [NSLocalizedDescriptionKey: "格式转换器创建失败"])
            }
            
            let outBuf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: framesToRead)!
            var error: NSError?
            let status = converter.convert(to: outBuf, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return tmpBuf
            }
            
            if status == .haveData {
                if gain != 1.0 {
                    applyGain(gain, to: outBuf)
                }
                player.scheduleBuffer(outBuf) { [weak self] in
                    DispatchQueue.main.async {
                        self?.scheduleNextIfNeeded()
                    }
                }
            } else {
                throw error ?? NSError(domain: "WaterEjector", code: 2, userInfo: [NSLocalizedDescriptionKey: "格式转换失败"])
            }
        } catch {
            print("文件转换失败: \(error)")
            scheduleNextIfNeeded()
        }
    }

    // MARK: - Buffers
    private func makeChirpBuffer(cfg: ChirpConfig, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(cfg.duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("无法创建音频缓冲区")
        }
        
        buffer.frameLength = frameCount

        let sr = format.sampleRate
        let k = (cfg.endHz - cfg.startHz) / cfg.duration
        let fadeSamples = Int(cfg.fade * sr)
        let totalSamples = Int(frameCount)

        for channel in 0..<Int(format.channelCount) {
            guard let channelData = buffer.floatChannelData?[channel] else { continue }
            
            for i in 0..<totalSamples {
                let t = Double(i) / sr
                let phase = 2.0 * Double.pi * (cfg.startHz * t + 0.5 * k * t * t)
                
                // 计算包络（淡入淡出）
                let envelope: Float
                if i < fadeSamples {
                    envelope = Float(i) / Float(fadeSamples)
                } else if i > totalSamples - fadeSamples {
                    envelope = Float(totalSamples - i) / Float(fadeSamples)
                } else {
                    envelope = 1.0
                }
                
                channelData[i] = sin(Float(phase)) * cfg.amplitude * envelope
            }
        }
        
        return buffer
    }

    private func makeSilenceBuffer(duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(max(0, duration) * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("无法创建静音缓冲区")
        }
        
        buffer.frameLength = frameCount
        for channel in 0..<Int(format.channelCount) {
            if let channelData = buffer.floatChannelData?[channel] {
                vDSP_vclr(channelData, 1, vDSP_Length(frameCount))
            }
        }
        return buffer
    }

    private func applyGain(_ gain: Float, to buffer: AVAudioPCMBuffer) {
        guard gain != 1.0 else { return }
        let frameLength = Int(buffer.frameLength)
        
        for channel in 0..<Int(buffer.format.channelCount) {
            if let channelData = buffer.floatChannelData?[channel] {
                var gainVector = gain
                vDSP_vsmul(channelData, 1, &gainVector, channelData, 1, vDSP_Length(frameLength))
            }
        }
    }

    // MARK: - Progress
    private func tickProgress() {
        progressTimer?.cancel()
        progressTimer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startTime = self.startTime, self.isRunning else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(1.0, elapsed / self.playlistTotalDuration)
                self.onProgress?(progress)
                
                if progress >= 1.0 {
                    self.progressTimer?.cancel()
                }
            }
    }

    private func computeTotalDuration(segments: [Segment]) -> TimeInterval {
        return segments.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Session & Route
    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        if config.preferSpeaker {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        } else {
            try session.setCategory(.playback, options: .mixWithOthers)
        }
        try session.setMode(.default)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func observeInterruption() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in
                guard let self = self,
                      let userInfo = note.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                
                switch type {
                case .began:
                    if self.isRunning {
                        self.player.pause()
                    }
                case .ended:
                    guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        if options.contains(.shouldResume), self.isRunning {
                            self.player.play()
                        }
                    } catch {
                        print("音频会话恢复失败: \(error)")
                    }
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func observeRouteChange() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] note in
                guard let self = self, self.isRunning,
                      let userInfo = note.userInfo,
                      let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
                
                // 只在路由真正改变时检查
                if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable {
                    if !self.isBuiltInSpeakerRoute() {
                        self.failAndStop("音频路由已改变")
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func isBuiltInSpeakerRoute() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        let outputs = currentRoute.outputs
        
        // 检查是否有耳机或蓝牙设备
        let hasHeadphones = outputs.contains { output in
            switch output.portType {
            case .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                return true
            default:
                return false
            }
        }
        
        // 检查是否使用内置扬声器或听筒
        let hasBuiltInOutput = outputs.contains { output in
            switch output.portType {
            case .builtInSpeaker, .builtInReceiver:
                return true
            default:
                return false
            }
        }
        
        return hasBuiltInOutput && !hasHeadphones
    }

    // MARK: - Finish helpers
    private func resetFinishFlag() {
        finishSent = false
    }

    private func finish(success: Bool, error: String?) {
        guard !finishSent else { return }
        finishSent = true
        DispatchQueue.main.async {
            self.onFinished?(success, error)
        }
    }

    private func failAndStop(_ message: String) {
        cleanup()
        finish(success: false, error: message)
    }
}

// MARK: - ViewModel
@MainActor
final class ClearWaveViewModel: ObservableObject {
    @Published var state: ClearWaveState = .guide
    @Published var progress: Double = 0
    @Published var showToast: Bool = false
    @Published var toastText: String = ""
    @Published var isFaceDown: Bool = false
    @Published var currentPattern: String = "准备中..."

    let faceDownMonitor = FaceDownMonitor()
    private var ejector = WaterEjector()

    init() {
        faceDownMonitor.$isFaceDown
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFaceDown)

        ejector.onProgress = { [weak self] progress in
            self?.progress = progress
        }

        ejector.onFinished = { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.state = .done
            } else {
                let errorMessage = error ?? "未知错误"
                self.toast(text: self.getUserFriendlyErrorMessage(errorMessage))
                self.state = .failed(errorMessage)
            }
        }
    }

    func onAppear() {
        faceDownMonitor.start()
    }

    func onDisappear() {
        faceDownMonitor.stop()
        if case .running = state {
            ejector.stop()
        }
    }

    func start() {
        guard state.canStart else { return }
        state = .running
        progress = 0
        currentPattern = "Up-Down Sweep 60s"
        ejector.startLegacy(totalDuration: 60, startHz: 300, endHz: 500, amplitude: 0.7)
    }

    func stopEarly() {
        ejector.stop()
    }

    func toast(text: String) {
        toastText = text
        withAnimation(.spring()) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring()) {
                self.showToast = false
            }
        }
    }

    private func getUserFriendlyErrorMessage(_ technicalError: String) -> String {
        if technicalError.contains("route") || technicalError.contains("耳机") || technicalError.contains("蓝牙") {
            return "请断开耳机或蓝牙设备，使用扬声器播放"
        } else if technicalError.contains("interruption") {
            return "播放被来电或通知中断"
        } else if technicalError.contains("启动失败") {
            return "音频系统启动失败，请重试"
        } else {
            return "排水过程出现问题，请重试"
        }
    }
}

// MARK: - UI
struct ClearWaveFlowView: View {
    @StateObject private var viewModel = ClearWaveViewModel()
    @EnvironmentObject var appRouterPath: RouterPath
    var body: some View {
        ZStack {
            Image("cleaning_home_bg")
                .resizable()
                .scaledToFill()
                .frame(width: kScreenWidth, height: kScreenHeight)
                .clipped()
                .ignoresSafeArea()

            Group {
                switch viewModel.state {
                case .guide:
                    GuidePage(onStart: { viewModel.start() })
                case .running:
                    RunningPage(
                        progress: viewModel.progress,
                        isFaceDown: viewModel.isFaceDown,
                        currentPattern: viewModel.currentPattern,
                        onStop: { viewModel.stopEarly() }
                    )
                case .done:
                    DonePage(onContinue: { appRouterPath.back() })
                case .failed:
                    GuidePage(onStart: { viewModel.start() })
                }
            }
            .transition(.opacity)
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                ClearWaveToastView(text: viewModel.toastText)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
    }
}

struct GuidePage: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Text("Clear Wave")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .padding(.top, 8)
            
            VStack(spacing: 8) {
                Text("Ready to Clear")
                    .font(.system(size: 28, weight: .heavy))
                Text("Tap to begin and let your iPhone breathe")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            ZStack {
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 260, height: 260)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 3)
                    )
                    .shadow(radius: 10)
                
                VStack(spacing: 14) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .padding(26)
                        .background(.ultraThinMaterial, in: Circle())
                    
                    Text("Click the button to start cleaning")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.75), in: Capsule())
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            Button(action: onStart) {
                Text("Start")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundColor(.white)
                    .shadow(radius: 4, y: 2)
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                Text("Sound will increase. Remove earphones.")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.red)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
}

struct RunningPage: View {
    let progress: Double
    let isFaceDown: Bool
    let currentPattern: String
    let onStop: () -> Void
    
    private var faceDownStatus: (text: String, color: Color, icon: String) {
        if isFaceDown {
            return ("设备已朝下 ✓", .green, "checkmark.circle.fill")
        } else {
            return ("请将设备屏幕朝下 👇", .orange, "exclamationmark.triangle.fill")
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)
            
            VStack(spacing: 16) {
                Text("Clear Wave 排水中")
                    .font(.system(size: 28, weight: .heavy))
                
                // 设备朝向状态
                HStack(spacing: 6) {
                    Image(systemName: faceDownStatus.icon)
                        .foregroundColor(faceDownStatus.color)
                    Text(faceDownStatus.text)
                        .foregroundColor(faceDownStatus.color)
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(faceDownStatus.color.opacity(0.1), in: Capsule())
                
                // 当前模式显示
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.blue)
                    Text("当前模式: \(currentPattern)")
                        .foregroundColor(.blue)
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1), in: Capsule())
            }
            .padding(.top, 12)
            
            Spacer()
            
            // 进度指示部分
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("排水进度")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 22, weight: .bold))
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }
            .padding(.horizontal, 24)
            
            Button(action: onStop) {
                Text("停止排水")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct DonePage: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 20)
            
            ZStack {
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 260, height: 260)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.blue)
                    .shadow(radius: 6)
            }
            
            VStack(spacing: 10) {
                Text("All Clear")
                    .font(.system(size: 32, weight: .heavy))
                
                Text("Your iPhone has finished water and dust removal")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct ClearWaveToastView: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .lineLimit(2)
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .foregroundColor(.white)
        .background(.black.opacity(0.85), in: Capsule())
        .padding(.horizontal, 16)
    }
}

// MARK: - 预览
struct ClearWaveFlowView_Previews: PreviewProvider {
    static var previews: some View {
        ClearWaveFlowView()
    }
}
