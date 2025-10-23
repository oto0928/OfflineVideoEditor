//
//  VideoEditorViewModel.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import AVFoundation
import Combine

/// 動画編集のビジネスロジックを管理するViewModel
class VideoEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentProject: VideoProject?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var selectedTool: EditorTool = .none
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var exportProgress: Double = 0
    
    // MARK: - Services
    
    private let videoEditorService = VideoEditorService.shared
    private let audioEditorService = AudioEditorService.shared
    private let subtitleService = SubtitleGenerationService.shared
    private let exportService = ExportService.shared
    
    // MARK: - Player
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    // MARK: - Initialization
    
    init() {
        setupPlayer()
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupPlayer() {
        player = AVPlayer()
        
        // 時間監視の設定
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
    
    // MARK: - Project Management
    
    /// 新しいプロジェクトを作成
    func createNewProject(name: String) {
        currentProject = VideoProject(name: name)
    }
    
    /// 動画を読み込む
    func loadVideo(from url: URL) {
        isLoading = true
        
        let asset = AVAsset(url: url)
        
        Task { @MainActor in
            do {
                let duration = try await asset.load(.duration)
                
                // プロジェクトが存在しない場合は新規作成
                if currentProject == nil {
                    currentProject = VideoProject(name: "新規プロジェクト")
                    print("📝 新規プロジェクトを作成しました")
                }
                
                // 動画情報を設定
                currentProject?.videoURL = url
                currentProject?.duration = duration.seconds
                
                print("✅ プロジェクトに動画を設定: \(url)")
                print("📊 動画時間: \(duration.seconds)秒")
                
                // プレーヤーに設定
                let playerItem = AVPlayerItem(asset: asset)
                player?.replaceCurrentItem(with: playerItem)
                
                print("🎬 プレーヤーに動画を設定しました")
                
                isLoading = false
            } catch {
                print("❌ 動画読み込みエラー: \(error)")
                errorMessage = "動画の読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Playback Control
    
    /// 再生/一時停止を切り替え
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    /// 指定時間にシーク
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTime = time
    }
    
    /// プレーヤーを取得
    func getPlayer() -> AVPlayer? {
        return player
    }
    
    // MARK: - Editing Operations
    
    /// 動画をトリミング
    func trimVideo(startTime: TimeInterval, endTime: TimeInterval) {
        guard let project = currentProject,
              let videoURL = project.videoURL else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        isLoading = true
        
        let asset = AVAsset(url: videoURL)
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.trimVideo(
            asset: asset,
            startTime: start,
            endTime: end,
            outputURL: outputURL
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 複数範囲をトリミング・結合
    func trimMultipleRanges(ranges: [(startTime: TimeInterval, endTime: TimeInterval)]) {
        guard let project = currentProject,
              let videoURL = project.videoURL,
              !ranges.isEmpty else {
            errorMessage = "プロジェクトまたは範囲が読み込まれていません"
            return
        }
        
        isLoading = true
        exportProgress = 0
        
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.trimMultipleRanges(
            asset: asset,
            ranges: ranges,
            outputURL: outputURL,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 字幕を自動生成
    func generateSubtitles(language: String = "ja-JP") {
        guard let project = currentProject,
              let videoURL = project.videoURL else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        isLoading = true
        
        let asset = AVAsset(url: videoURL)
        
        subtitleService.generateSubtitles(
            from: asset,
            language: language,
            progress: { progress in
                DispatchQueue.main.async {
                    self.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let subtitles):
                    self?.currentProject?.subtitles = subtitles
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// プロジェクトをエクスポート
    func exportProject(settings: ExportService.ExportSettings, outputURL: URL) {
        guard let project = currentProject else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        isLoading = true
        exportProgress = 0
        
        exportService.exportProject(
            project,
            settings: settings,
            outputURL: outputURL,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    print("エクスポート成功: \(url)")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 複数の動画を結合
    func mergeVideos(urls: [URL]) {
        guard !urls.isEmpty else {
            errorMessage = "結合する動画がありません"
            return
        }
        
        isLoading = true
        
        let assets = urls.map { AVAsset(url: $0) }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.mergeVideos(
            assets: assets,
            outputURL: outputURL
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 動画のサイズを変更
    func resizeVideo(width: Int, height: Int, maintainAspectRatio: Bool) {
        guard let project = currentProject,
              let videoURL = project.videoURL else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        isLoading = true
        
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        let targetSize = CGSize(width: width, height: height)
        
        videoEditorService.resizeVideo(
            asset: asset,
            targetSize: targetSize,
            maintainAspectRatio: maintainAspectRatio,
            outputURL: outputURL
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 動画をクロップ
    func cropVideo(cropRect: CGRect) {
        guard let project = currentProject,
              let videoURL = project.videoURL else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        isLoading = true
        exportProgress = 0
        
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.cropVideo(
            asset: asset,
            cropRect: cropRect,
            outputURL: outputURL,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 動画を回転
    func rotateVideo(angle: RotationAngle) {
        guard let project = currentProject,
              let videoURL = project.videoURL else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        isLoading = true
        exportProgress = 0
        
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.rotateVideo(
            asset: asset,
            rotation: angle.transform,
            outputURL: outputURL,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// 字幕を動画に焼き込む
    func burnSubtitlesToVideo() {
        guard let project = currentProject,
              let videoURL = project.videoURL,
              !project.subtitles.isEmpty else {
            errorMessage = "プロジェクトまたは字幕が読み込まれていません"
            return
        }
        
        isLoading = true
        exportProgress = 0
        
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.burnSubtitles(
            asset: asset,
            subtitles: project.subtitles,
            outputURL: outputURL,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Overlay Operations
    
    /// 画像オーバーレイを追加
    func addImageOverlay(imageURL: URL) {
        guard currentProject != nil else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        var overlay = Overlay(
            type: .image,
            startTime: 0,
            endTime: min(5.0, currentProject?.duration ?? 5.0),
            position: OverlayPosition(x: 0.5, y: 0.5),
            size: OverlaySize(width: 0.3, height: 0.3)
        )
        overlay.imageURL = imageURL
        
        currentProject?.overlays.append(overlay)
    }
    
    /// テキストオーバーレイを追加
    func addTextOverlay(overlay: Overlay) {
        guard currentProject != nil else {
            errorMessage = "プロジェクトが読み込まれていません"
            return
        }
        
        currentProject?.overlays.append(overlay)
    }
    
    /// オーバーレイを削除
    func deleteOverlay(id: UUID) {
        currentProject?.overlays.removeAll { $0.id == id }
    }
    
    /// オーバーレイを動画に適用
    func applyOverlaysToVideo() {
        guard let project = currentProject,
              let videoURL = project.videoURL,
              !project.overlays.isEmpty else {
            errorMessage = "プロジェクトまたはオーバーレイが読み込まれていません"
            return
        }
        
        isLoading = true
        exportProgress = 0
        
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        videoEditorService.applyOverlays(
            asset: asset,
            overlays: project.overlays,
            outputURL: outputURL,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.exportProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let url):
                    self?.loadVideo(from: url)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Editor Tools

enum EditorTool {
    case none
    case trim
    case cut
    case split
    case merge
    case subtitle
    case text
    case effect
    case audio
    case speed
    case rotate
    case crop
}

