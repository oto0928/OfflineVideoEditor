//
//  AudioEditorService.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import AVFoundation

/// 音声編集機能を提供するサービス
class AudioEditorService {
    
    // MARK: - Singleton
    static let shared = AudioEditorService()
    private init() {}
    
    // MARK: - Volume Adjustment
    
    /// 音量を調整する
    /// - Parameters:
    ///   - asset: 元の音声/動画アセット
    ///   - volume: 音量レベル（0.0 - 1.0）
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func adjustVolume(
        asset: AVAsset,
        volume: Float,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetAudioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(.failure(AudioEditorError.trackCreationFailed))
            return
        }
        
        let duration = asset.duration
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        do {
            try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            
            // 音量調整のためのオーディオミックスパラメータを作成
            let audioMix = AVMutableAudioMix()
            let audioMixParam = AVMutableAudioMixInputParameters(track: audioTrack)
            audioMixParam.setVolume(volume, at: .zero)
            audioMix.inputParameters = [audioMixParam]
            
            exportComposition(composition, to: outputURL, audioMix: audioMix, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Fade In/Out
    
    /// フェードイン/フェードアウト効果を適用する
    /// - Parameters:
    ///   - asset: 元の音声/動画アセット
    ///   - fadeInDuration: フェードイン時間
    ///   - fadeOutDuration: フェードアウト時間
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func applyFade(
        asset: AVAsset,
        fadeInDuration: TimeInterval,
        fadeOutDuration: TimeInterval,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetAudioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(.failure(AudioEditorError.trackCreationFailed))
            return
        }
        
        let duration = asset.duration
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        do {
            try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            
            let audioMix = AVMutableAudioMix()
            let audioMixParam = AVMutableAudioMixInputParameters(track: audioTrack)
            
            // フェードイン
            if fadeInDuration > 0 {
                audioMixParam.setVolume(0.0, at: .zero)
                let fadeInTime = CMTime(seconds: fadeInDuration, preferredTimescale: 600)
                audioMixParam.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 1.0, timeRange: CMTimeRange(start: .zero, duration: fadeInTime))
            }
            
            // フェードアウト
            if fadeOutDuration > 0 {
                let fadeOutStartTime = CMTimeSubtract(duration, CMTime(seconds: fadeOutDuration, preferredTimescale: 600))
                let fadeOutDuration = CMTime(seconds: fadeOutDuration, preferredTimescale: 600)
                audioMixParam.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: CMTimeRange(start: fadeOutStartTime, duration: fadeOutDuration))
            }
            
            audioMix.inputParameters = [audioMixParam]
            
            exportComposition(composition, to: outputURL, audioMix: audioMix, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Mix Audio
    
    /// 複数の音声トラックをミックスする
    /// - Parameters:
    ///   - videoAsset: 元の動画アセット
    ///   - audioTracks: 追加する音声トラックの配列
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func mixAudio(
        videoAsset: AVAsset,
        audioTracks: [AudioTrack],
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        
        // ビデオトラックを追加
        if let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetVideoTrack = videoAsset.tracks(withMediaType: .video).first {
            let duration = videoAsset.duration
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            do {
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        // オリジナル音声トラックを追加
        if let originalAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetAudioTrack = videoAsset.tracks(withMediaType: .audio).first {
            let duration = videoAsset.duration
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            do {
                try originalAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        // 追加の音声トラックをミックス
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []
        
        for (index, audioTrack) in audioTracks.enumerated() {
            guard let audioURL = audioTrack.audioURL else { continue }
            
            let audioAsset = AVAsset(url: audioURL)
            
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let sourceAudioTrack = audioAsset.tracks(withMediaType: .audio).first else {
                continue
            }
            
            let startTime = CMTime(seconds: audioTrack.startTime, preferredTimescale: 600)
            let duration = CMTime(seconds: audioTrack.duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            do {
                try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: startTime)
                
                let audioMixParam = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                audioMixParam.setVolume(audioTrack.volume, at: .zero)
                
                // フェードイン/アウト
                if audioTrack.fadeIn > 0 {
                    let fadeInTime = CMTime(seconds: audioTrack.fadeIn, preferredTimescale: 600)
                    audioMixParam.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: audioTrack.volume, timeRange: CMTimeRange(start: startTime, duration: fadeInTime))
                }
                
                if audioTrack.fadeOut > 0 {
                    let fadeOutStartTime = CMTimeAdd(startTime, CMTimeSubtract(duration, CMTime(seconds: audioTrack.fadeOut, preferredTimescale: 600)))
                    let fadeOutDuration = CMTime(seconds: audioTrack.fadeOut, preferredTimescale: 600)
                    audioMixParam.setVolumeRamp(fromStartVolume: audioTrack.volume, toEndVolume: 0.0, timeRange: CMTimeRange(start: fadeOutStartTime, duration: fadeOutDuration))
                }
                
                inputParameters.append(audioMixParam)
            } catch {
                continue
            }
        }
        
        audioMix.inputParameters = inputParameters
        
        exportComposition(composition, to: outputURL, audioMix: audioMix, completion: completion)
    }
    
    // MARK: - Extract Audio
    
    /// 動画から音声を抽出する
    /// - Parameters:
    ///   - videoAsset: 元の動画アセット
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func extractAudio(
        from videoAsset: AVAsset,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let exportSession = AVAssetExportSession(
            asset: videoAsset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            completion(.failure(AudioEditorError.exportSessionCreationFailed))
            return
        }
        
        // 既存ファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? AudioEditorError.exportFailed))
            case .cancelled:
                completion(.failure(AudioEditorError.exportCancelled))
            default:
                completion(.failure(AudioEditorError.exportFailed))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// コンポジションをエクスポートする
    private func exportComposition(
        _ composition: AVMutableComposition,
        to outputURL: URL,
        audioMix: AVAudioMix? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 既存ファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            completion(.failure(AudioEditorError.exportSessionCreationFailed))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? AudioEditorError.exportFailed))
            case .cancelled:
                completion(.failure(AudioEditorError.exportCancelled))
            default:
                completion(.failure(AudioEditorError.exportFailed))
            }
        }
    }
}

// MARK: - Error Types

enum AudioEditorError: LocalizedError {
    case exportSessionCreationFailed
    case trackCreationFailed
    case exportFailed
    case exportCancelled
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "エクスポートセッションの作成に失敗しました"
        case .trackCreationFailed:
            return "トラックの作成に失敗しました"
        case .exportFailed:
            return "エクスポートに失敗しました"
        case .exportCancelled:
            return "エクスポートがキャンセルされました"
        case .invalidInput:
            return "無効な入力です"
        }
    }
}

