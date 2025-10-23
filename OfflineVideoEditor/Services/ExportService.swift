//
//  ExportService.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import AVFoundation
import UIKit

/// 動画エクスポート機能を提供するサービス
class ExportService {
    
    // MARK: - Singleton
    static let shared = ExportService()
    private init() {}
    
    // MARK: - Export Settings
    
    struct ExportSettings {
        var resolution: VideoResolution
        var frameRate: Double
        var aspectRatio: AspectRatio
        var bitRate: Int
        var quality: ExportQuality
        
        init(
            resolution: VideoResolution = .hd1080,
            frameRate: Double = 30.0,
            aspectRatio: AspectRatio = .aspect16_9,
            bitRate: Int = 8000000,
            quality: ExportQuality = .high
        ) {
            self.resolution = resolution
            self.frameRate = frameRate
            self.aspectRatio = aspectRatio
            self.bitRate = bitRate
            self.quality = quality
        }
    }
    
    enum ExportQuality: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case highest = "Highest"
        
        var preset: String {
            switch self {
            case .low:
                return AVAssetExportPresetLowQuality
            case .medium:
                return AVAssetExportPresetMediumQuality
            case .high:
                return AVAssetExportPresetHighestQuality
            case .highest:
                return AVAssetExportPresetHighestQuality
            }
        }
    }
    
    // MARK: - Export Project
    
    /// プロジェクトをエクスポートする
    /// - Parameters:
    ///   - project: エクスポートするプロジェクト
    ///   - settings: エクスポート設定
    ///   - outputURL: 出力先URL
    ///   - progress: 進捗ハンドラ
    ///   - completion: 完了ハンドラ
    func exportProject(
        _ project: VideoProject,
        settings: ExportSettings,
        outputURL: URL,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // コンポジションを作成
        guard let composition = createComposition(from: project, settings: settings) else {
            completion(.failure(ExportError.compositionCreationFailed))
            return
        }
        
        // ビデオコンポジションを作成
        let videoComposition = createVideoComposition(
            for: composition,
            project: project,
            settings: settings
        )
        
        // オーディオミックスを作成
        let audioMix = createAudioMix(for: composition, project: project)
        
        // エクスポート実行
        exportComposition(
            composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            settings: settings,
            outputURL: outputURL,
            progress: progress,
            completion: completion
        )
    }
    
    // MARK: - Private Methods
    
    /// コンポジションを作成
    private func createComposition(
        from project: VideoProject,
        settings: ExportSettings
    ) -> AVMutableComposition? {
        let composition = AVMutableComposition()
        
        // ビデオトラックを作成
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }
        
        // オーディオトラックを作成
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }
        
        // タイムラインアイテムを追加
        var currentTime = CMTime.zero
        
        for item in project.timelineItems.sorted(by: { $0.startTime < $1.startTime }) {
            switch item.type {
            case .video(let clip):
                if let asset = try? AVAsset(url: clip.url),
                   let assetVideoTrack = asset.tracks(withMediaType: .video).first {
                    let duration = CMTime(seconds: item.duration / clip.speed, preferredTimescale: 600)
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    
                    do {
                        try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                        
                        if let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                            try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                        }
                        
                        currentTime = CMTimeAdd(currentTime, duration)
                    } catch {
                        print("Error inserting video clip: \(error)")
                    }
                }
            default:
                break
            }
        }
        
        return composition
    }
    
    /// ビデオコンポジションを作成
    private func createVideoComposition(
        for composition: AVMutableComposition,
        project: VideoProject,
        settings: ExportSettings
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        
        // 解像度とアスペクト比を設定
        let size = calculateSize(for: settings)
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(settings.frameRate))
        
        // エフェクトとオーバーレイを適用
        let instructions = createVideoInstructions(
            for: composition,
            project: project,
            size: size
        )
        videoComposition.instructions = instructions
        
        return videoComposition
    }
    
    /// ビデオインストラクションを作成
    private func createVideoInstructions(
        for composition: AVMutableComposition,
        project: VideoProject,
        size: CGSize
    ) -> [AVVideoCompositionInstruction] {
        var instructions: [AVVideoCompositionInstruction] = []
        
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            return instructions
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // トランスフォームを設定（アスペクト比調整など）
        let transform = calculateTransform(for: videoTrack, targetSize: size)
        layerInstruction.setTransform(transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        instructions.append(instruction)
        
        return instructions
    }
    
    /// オーディオミックスを作成
    private func createAudioMix(
        for composition: AVMutableComposition,
        project: VideoProject
    ) -> AVMutableAudioMix {
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []
        
        for audioTrack in composition.tracks(withMediaType: .audio) {
            let param = AVMutableAudioMixInputParameters(track: audioTrack)
            param.setVolume(1.0, at: .zero)
            inputParameters.append(param)
        }
        
        audioMix.inputParameters = inputParameters
        
        return audioMix
    }
    
    /// サイズを計算
    private func calculateSize(for settings: ExportSettings) -> CGSize {
        let baseSize = settings.resolution.size
        let ratio = settings.aspectRatio.ratio
        
        // アスペクト比に合わせてサイズを調整
        var width = baseSize.width
        var height = baseSize.height
        
        let currentRatio = width / height
        
        if abs(currentRatio - ratio) > 0.01 {
            if ratio > currentRatio {
                width = height * ratio
            } else {
                height = width / ratio
            }
        }
        
        return CGSize(width: width, height: height)
    }
    
    /// トランスフォームを計算
    private func calculateTransform(
        for track: AVAssetTrack,
        targetSize: CGSize
    ) -> CGAffineTransform {
        let trackSize = track.naturalSize
        let trackTransform = track.preferredTransform
        
        // スケールを計算
        let scaleX = targetSize.width / trackSize.width
        let scaleY = targetSize.height / trackSize.height
        let scale = min(scaleX, scaleY)
        
        var transform = trackTransform
        transform = transform.scaledBy(x: scale, y: scale)
        
        // センタリング
        let scaledWidth = trackSize.width * scale
        let scaledHeight = trackSize.height * scale
        let offsetX = (targetSize.width - scaledWidth) / 2.0
        let offsetY = (targetSize.height - scaledHeight) / 2.0
        transform = transform.translatedBy(x: offsetX, y: offsetY)
        
        return transform
    }
    
    /// コンポジションをエクスポート
    private func exportComposition(
        _ composition: AVMutableComposition,
        videoComposition: AVVideoComposition,
        audioMix: AVAudioMix,
        settings: ExportSettings,
        outputURL: URL,
        progress: ((Double) -> Void)?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 既存ファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: settings.quality.preset
        ) else {
            completion(.failure(ExportError.exportSessionCreationFailed))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.audioMix = audioMix
        
        // 進捗監視
        if let progressHandler = progress {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                progressHandler(Double(exportSession.progress))
            }
            
            exportSession.exportAsynchronously {
                timer.invalidate()
                
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? ExportError.exportFailed))
                case .cancelled:
                    completion(.failure(ExportError.exportCancelled))
                default:
                    completion(.failure(ExportError.exportFailed))
                }
            }
        } else {
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? ExportError.exportFailed))
                case .cancelled:
                    completion(.failure(ExportError.exportCancelled))
                default:
                    completion(.failure(ExportError.exportFailed))
                }
            }
        }
    }
}

// MARK: - Error Types

enum ExportError: LocalizedError {
    case compositionCreationFailed
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .compositionCreationFailed:
            return "コンポジションの作成に失敗しました"
        case .exportSessionCreationFailed:
            return "エクスポートセッションの作成に失敗しました"
        case .exportFailed:
            return "エクスポートに失敗しました"
        case .exportCancelled:
            return "エクスポートがキャンセルされました"
        }
    }
}

