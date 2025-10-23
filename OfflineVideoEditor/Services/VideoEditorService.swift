//
//  VideoEditorService.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import AVFoundation
import UIKit

/// 動画編集機能を提供するサービス
class VideoEditorService {
    
    // MARK: - Singleton
    static let shared = VideoEditorService()
    private init() {}
    
    // MARK: - Trimming
    
    /// 動画をトリミングする
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - startTime: 開始時間
    ///   - endTime: 終了時間
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func trimVideo(
        asset: AVAsset,
        startTime: CMTime,
        endTime: CMTime,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(VideoEditorError.exportSessionCreationFailed))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? VideoEditorError.exportFailed))
            case .cancelled:
                completion(.failure(VideoEditorError.exportCancelled))
            default:
                completion(.failure(VideoEditorError.exportFailed))
            }
        }
    }
    
    /// 複数範囲をトリミングして結合する
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - ranges: トリミング範囲の配列 [(開始時間, 終了時間)]
    ///   - outputURL: 出力先URL
    ///   - progress: 進捗コールバック
    ///   - completion: 完了ハンドラ
    func trimMultipleRanges(
        asset: AVAsset,
        ranges: [(startTime: TimeInterval, endTime: TimeInterval)],
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !ranges.isEmpty else {
            completion(.failure(VideoEditorError.invalidInput))
            return
        }
        
        let composition = AVMutableComposition()
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(.failure(VideoEditorError.trackCreationFailed))
            return
        }
        
        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
                
                var currentTime = CMTime.zero
                
                // 各範囲を順番に結合
                for (index, range) in ranges.enumerated() {
                    let startTime = CMTime(seconds: range.startTime, preferredTimescale: 600)
                    let endTime = CMTime(seconds: range.endTime, preferredTimescale: 600)
                    let duration = CMTimeSubtract(endTime, startTime)
                    let timeRange = CMTimeRange(start: startTime, duration: duration)
                    
                    // ビデオトラックを追加
                    try compositionVideoTrack.insertTimeRange(
                        timeRange,
                        of: videoTrack,
                        at: currentTime
                    )
                    
                    // オーディオトラックを追加
                    if let audioTrack = audioTrack {
                        try? compositionAudioTrack.insertTimeRange(
                            timeRange,
                            of: audioTrack,
                            at: currentTime
                        )
                    }
                    
                    currentTime = CMTimeAdd(currentTime, duration)
                    
                    // 進捗報告
                    let progressValue = Double(index + 1) / Double(ranges.count) * 0.5
                    progress(progressValue)
                }
                
                // エクスポート
                exportComposition(
                    composition,
                    to: outputURL,
                    videoComposition: nil,
                    progress: { exportProgress in
                        progress(0.5 + exportProgress * 0.5)
                    },
                    completion: completion
                )
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Merging
    
    /// 複数の動画を結合する
    /// - Parameters:
    ///   - assets: 結合する動画アセットの配列
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func mergeVideos(
        assets: [AVAsset],
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(.failure(VideoEditorError.trackCreationFailed))
            return
        }
        
        var currentTime = CMTime.zero
        
        for asset in assets {
            guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                continue
            }
            
            let duration = asset.duration
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            do {
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                
                if let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                }
                
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        exportComposition(composition, to: outputURL, completion: completion)
    }
    
    // MARK: - Speed Change
    
    /// 動画の再生速度を変更する
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - speed: 速度倍率（0.5 = 50%速度、2.0 = 200%速度）
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func changeSpeed(
        asset: AVAsset,
        speed: Double,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(VideoEditorError.trackCreationFailed))
            return
        }
        
        let duration = asset.duration
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        do {
            try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
            
            if let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            }
            
            let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / speed)
            videoTrack.scaleTimeRange(timeRange, toDuration: scaledDuration)
            
            exportComposition(composition, to: outputURL, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Rotation
    
    /// 動画を回転する
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - rotation: 回転トランスフォーム
    ///   - outputURL: 出力先URL
    ///   - progress: 進捗コールバック
    ///   - completion: 完了ハンドラ
    func rotateVideo(
        asset: AVAsset,
        rotation: CGAffineTransform,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let duration = try await asset.load(.duration)
                
                // 新しいトランスフォームを計算
                let newTransform = preferredTransform.concatenating(rotation)
                
                // 回転後のサイズを計算
                let rotatedSize = naturalSize.applying(rotation)
                let finalSize = CGSize(
                    width: abs(rotatedSize.width),
                    height: abs(rotatedSize.height)
                )
                
                // コンポジション作成
                let composition = AVMutableComposition()
                
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                // 音声トラックも追加
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                   ) {
                    try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
                
                // ビデオコンポジション作成
                let videoComposition = AVMutableVideoComposition()
                videoComposition.renderSize = finalSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                
                // 回転の中心を調整
                var adjustedTransform = newTransform
                
                // 回転角度に応じて位置を調整
                if rotation.a == 0 && rotation.b == 1 && rotation.c == -1 && rotation.d == 0 {
                    // 90度回転
                    adjustedTransform = adjustedTransform.translatedBy(x: 0, y: -finalSize.width)
                } else if rotation.a == -1 && rotation.b == 0 && rotation.c == 0 && rotation.d == -1 {
                    // 180度回転
                    adjustedTransform = adjustedTransform.translatedBy(x: -finalSize.width, y: -finalSize.height)
                } else if rotation.a == 0 && rotation.b == -1 && rotation.c == 1 && rotation.d == 0 {
                    // 270度回転
                    adjustedTransform = adjustedTransform.translatedBy(x: -finalSize.height, y: 0)
                }
                
                layerInstruction.setTransform(adjustedTransform, at: .zero)
                
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                
                // エクスポート
                exportComposition(
                    composition,
                    to: outputURL,
                    videoComposition: videoComposition,
                    progress: progress,
                    completion: completion
                )
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Crop
    
    /// 動画をクロップする
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - cropRect: クロップ領域
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func cropVideo(
        asset: AVAsset,
        cropRect: CGRect,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(VideoEditorError.trackCreationFailed))
            return
        }
        
        let duration = asset.duration
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        do {
            try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
            
            // ビデオコンポジション設定
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = cropRect.size
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRange
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            
            var transform = assetVideoTrack.preferredTransform
            transform = transform.translatedBy(x: -cropRect.origin.x, y: -cropRect.origin.y)
            layerInstruction.setTransform(transform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            exportComposition(composition, to: outputURL, videoComposition: videoComposition, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Resize
    
    /// 動画のサイズを変更する
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - targetSize: 目標サイズ
    ///   - maintainAspectRatio: 縦横比を維持するかどうか
    ///   - outputURL: 出力先URL
    ///   - completion: 完了ハンドラ
    func resizeVideo(
        asset: AVAsset,
        targetSize: CGSize,
        maintainAspectRatio: Bool,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                
                // 実際の動画サイズを計算（回転を考慮）
                let videoSize: CGSize
                let isPortrait = preferredTransform.a == 0 && preferredTransform.d == 0
                if isPortrait {
                    videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                } else {
                    videoSize = naturalSize
                }
                
                // 最終的な出力サイズを計算
                let finalSize: CGSize
                if maintainAspectRatio {
                    let aspectRatio = videoSize.width / videoSize.height
                    let targetAspectRatio = targetSize.width / targetSize.height
                    
                    if aspectRatio > targetAspectRatio {
                        // 幅に合わせる
                        finalSize = CGSize(
                            width: targetSize.width,
                            height: targetSize.width / aspectRatio
                        )
                    } else {
                        // 高さに合わせる
                        finalSize = CGSize(
                            width: targetSize.height * aspectRatio,
                            height: targetSize.height
                        )
                    }
                } else {
                    finalSize = targetSize
                }
                
                // コンポジション作成
                let composition = AVMutableComposition()
                
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                // 音声トラックも追加
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                   ) {
                    try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
                
                // ビデオコンポジション設定
                let videoComposition = AVMutableVideoComposition()
                videoComposition.renderSize = finalSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                
                // スケールとトランスフォームを計算
                let scaleX = finalSize.width / videoSize.width
                let scaleY = finalSize.height / videoSize.height
                
                var transform = preferredTransform
                transform = transform.scaledBy(x: scaleX, y: scaleY)
                
                layerInstruction.setTransform(transform, at: .zero)
                
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                
                exportComposition(composition, to: outputURL, videoComposition: videoComposition, completion: completion)
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Crop
    
    /// 動画をクロップする
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - cropRect: クロップ範囲（0.0〜1.0の相対座標）
    ///   - outputURL: 出力先URL
    ///   - progress: 進捗コールバック
    ///   - completion: 完了ハンドラ
    func cropVideo(
        asset: AVAsset,
        cropRect: CGRect,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let duration = try await asset.load(.duration)
                
                // 実際の動画サイズを計算（回転を考慮）
                let videoSize: CGSize
                let isPortrait = preferredTransform.a == 0 && preferredTransform.d == 0
                if isPortrait {
                    videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                } else {
                    videoSize = naturalSize
                }
                
                // クロップ範囲をピクセル座標に変換
                let cropX = cropRect.origin.x * videoSize.width
                let cropY = cropRect.origin.y * videoSize.height
                let cropWidth = cropRect.width * videoSize.width
                let cropHeight = cropRect.height * videoSize.height
                
                let cropRectInPixels = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
                
                // コンポジション作成
                let composition = AVMutableComposition()
                
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                // 音声トラックも追加
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                   ) {
                    try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
                
                // ビデオコンポジション作成
                let videoComposition = AVMutableVideoComposition()
                videoComposition.renderSize = CGSize(width: cropWidth, height: cropHeight)
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                
                // クロップのためのトランスフォームを計算
                var transform = preferredTransform
                
                // クロップ位置を調整（原点をクロップ範囲の左上に移動）
                transform = transform.translatedBy(x: -cropX, y: -cropY)
                
                layerInstruction.setTransform(transform, at: .zero)
                
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                
                // エクスポート
                exportComposition(
                    composition,
                    to: outputURL,
                    videoComposition: videoComposition,
                    progress: progress,
                    completion: completion
                )
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Burn Subtitles
    
    /// 字幕を動画に焼き込む
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - subtitles: 字幕データ
    ///   - outputURL: 出力先URL
    ///   - progress: 進捗コールバック
    ///   - completion: 完了ハンドラ
    func burnSubtitles(
        asset: AVAsset,
        subtitles: [Subtitle],
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let duration = try await asset.load(.duration)
                
                // 回転を考慮した実際の表示サイズを計算
                let videoSize: CGSize
                let isPortrait = preferredTransform.a == 0 && preferredTransform.d == 0
                if isPortrait {
                    videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                } else {
                    videoSize = naturalSize
                }
                
                // コンポジション作成
                let composition = AVMutableComposition()
                
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                // 音声トラックも追加
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                   ) {
                    try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
                
                // ビデオコンポジション作成
                let videoComposition = AVMutableVideoComposition()
                videoComposition.renderSize = videoSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                // 字幕レイヤーを追加
                let parentLayer = CALayer()
                let videoLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: videoSize)
                videoLayer.frame = CGRect(origin: .zero, size: videoSize)
                
                // Core Animationの座標系を反転（Y軸を上から下へ）
                parentLayer.isGeometryFlipped = true
                
                parentLayer.addSublayer(videoLayer)
                
                // 各字幕をレイヤーとして追加
                for subtitle in subtitles {
                    let textLayer = createSubtitleLayer(
                        subtitle: subtitle,
                        videoSize: videoSize
                    )
                    parentLayer.addSublayer(textLayer)
                }
                
                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                    postProcessingAsVideoLayer: videoLayer,
                    in: parentLayer
                )
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: compositionVideoTrack
                )
                
                // 元の動画のトランスフォームを適用
                layerInstruction.setTransform(preferredTransform, at: .zero)
                
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                
                // エクスポート
                exportComposition(
                    composition,
                    to: outputURL,
                    videoComposition: videoComposition,
                    progress: progress,
                    completion: completion
                )
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// 字幕用のCATextLayerを作成
    private func createSubtitleLayer(subtitle: Subtitle, videoSize: CGSize) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.contentsScale = UIScreen.main.scale // Retina対応
        
        // フォント設定
        let fontSize = subtitle.style.fontSize
        let fontName = subtitle.style.fontName == "System" ? "Helvetica-Bold" : subtitle.style.fontName
        
        if let font = CGFont(fontName as CFString) {
            textLayer.font = font
        }
        textLayer.fontSize = fontSize
        
        // テキスト設定
        textLayer.string = subtitle.text
        textLayer.alignmentMode = .center
        textLayer.truncationMode = .none
        textLayer.isWrapped = true
        
        textLayer.foregroundColor = UIColor(
            red: subtitle.style.fontColor.red,
            green: subtitle.style.fontColor.green,
            blue: subtitle.style.fontColor.blue,
            alpha: subtitle.style.fontColor.alpha
        ).cgColor
        
        // 背景色設定
        if subtitle.style.backgroundColor.alpha > 0 {
            textLayer.backgroundColor = UIColor(
                red: subtitle.style.backgroundColor.red,
                green: subtitle.style.backgroundColor.green,
                blue: subtitle.style.backgroundColor.blue,
                alpha: subtitle.style.backgroundColor.alpha
            ).cgColor
            textLayer.cornerRadius = 4
        }
        
        // レイヤーのサイズと位置
        let textWidth = videoSize.width * 0.9
        let textHeight = fontSize * 3 // 3行分のスペース
        let yPosition: CGFloat
        
        switch subtitle.position {
        case .top:
            yPosition = videoSize.height * 0.1
        case .center:
            yPosition = (videoSize.height - textHeight) / 2
        case .bottom:
            yPosition = videoSize.height - textHeight - (videoSize.height * 0.1)
        case .custom:
            yPosition = videoSize.height - textHeight - (videoSize.height * 0.1)
        }
        
        textLayer.frame = CGRect(
            x: (videoSize.width - textWidth) / 2,
            y: yPosition,
            width: textWidth,
            height: textHeight
        )
        
        // アニメーショングループを作成
        let animationGroup = CAAnimationGroup()
        animationGroup.beginTime = AVCoreAnimationBeginTimeAtZero + subtitle.startTime
        animationGroup.duration = subtitle.endTime - subtitle.startTime
        animationGroup.fillMode = .both
        animationGroup.isRemovedOnCompletion = false
        
        // 表示アニメーション
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.2
        fadeIn.beginTime = 0
        fadeIn.fillMode = .forwards
        
        // 非表示アニメーション
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = 0.2
        fadeOut.beginTime = animationGroup.duration - 0.2
        fadeOut.fillMode = .forwards
        
        animationGroup.animations = [fadeIn, fadeOut]
        
        textLayer.add(animationGroup, forKey: "subtitle_\(subtitle.id)")
        
        // 初期状態は非表示
        textLayer.opacity = 0
        
        return textLayer
    }
    
    // MARK: - Apply Overlays
    
    /// オーバーレイを動画に適用
    /// - Parameters:
    ///   - asset: 元の動画アセット
    ///   - overlays: オーバーレイデータ
    ///   - outputURL: 出力先URL
    ///   - progress: 進捗コールバック
    ///   - completion: 完了ハンドラ
    func applyOverlays(
        asset: AVAsset,
        overlays: [Overlay],
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let duration = try await asset.load(.duration)
                
                // 回転を考慮した実際の表示サイズを計算
                let videoSize: CGSize
                let isPortrait = preferredTransform.a == 0 && preferredTransform.d == 0
                if isPortrait {
                    videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                } else {
                    videoSize = naturalSize
                }
                
                // コンポジション作成
                let composition = AVMutableComposition()
                
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    completion(.failure(VideoEditorError.trackCreationFailed))
                    return
                }
                
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                // 音声トラックも追加
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                   ) {
                    try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
                
                // ビデオコンポジション作成
                let videoComposition = AVMutableVideoComposition()
                videoComposition.renderSize = videoSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                // オーバーレイレイヤーを追加
                let parentLayer = CALayer()
                let videoLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: videoSize)
                videoLayer.frame = CGRect(origin: .zero, size: videoSize)
                
                // Core Animationの座標系を反転（Y軸を上から下へ）
                parentLayer.isGeometryFlipped = true
                
                parentLayer.addSublayer(videoLayer)
                
                // 各オーバーレイをレイヤーとして追加
                for overlay in overlays {
                    if overlay.type == .image, let imageURL = overlay.imageURL {
                        let imageLayer = createImageLayer(
                            overlay: overlay,
                            imageURL: imageURL,
                            videoSize: videoSize
                        )
                        parentLayer.addSublayer(imageLayer)
                    } else if overlay.type == .text, let text = overlay.text, let style = overlay.textStyle {
                        let textLayer = createTextOverlayLayer(
                            overlay: overlay,
                            text: text,
                            style: style,
                            videoSize: videoSize
                        )
                        parentLayer.addSublayer(textLayer)
                    }
                }
                
                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                    postProcessingAsVideoLayer: videoLayer,
                    in: parentLayer
                )
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: compositionVideoTrack
                )
                
                // 元の動画のトランスフォームを適用
                layerInstruction.setTransform(preferredTransform, at: .zero)
                
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
                
                // エクスポート
                exportComposition(
                    composition,
                    to: outputURL,
                    videoComposition: videoComposition,
                    progress: progress,
                    completion: completion
                )
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// 画像レイヤーを作成
    private func createImageLayer(overlay: Overlay, imageURL: URL, videoSize: CGSize) -> CALayer {
        let imageLayer = CALayer()
        imageLayer.contentsScale = UIScreen.main.scale
        
        // 画像を読み込み
        if let image = UIImage(contentsOfFile: imageURL.path) {
            imageLayer.contents = image.cgImage
        }
        
        // レイヤーのサイズと位置
        let width = videoSize.width * overlay.size.width
        let height = videoSize.height * overlay.size.height
        let x = (videoSize.width * overlay.position.x) - (width / 2)
        let y = (videoSize.height * overlay.position.y) - (height / 2)
        
        imageLayer.frame = CGRect(x: x, y: y, width: width, height: height)
        imageLayer.contentsGravity = .resizeAspect
        
        // 表示タイミング設定
        imageLayer.opacity = 0
        
        // アニメーショングループを作成
        let animationGroup = CAAnimationGroup()
        animationGroup.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.startTime
        animationGroup.duration = overlay.endTime - overlay.startTime
        animationGroup.fillMode = .both
        animationGroup.isRemovedOnCompletion = false
        
        // フェードイン
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.3
        fadeIn.beginTime = 0
        fadeIn.fillMode = .forwards
        
        // フェードアウト
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = 0.3
        fadeOut.beginTime = max(0, animationGroup.duration - 0.3)
        fadeOut.fillMode = .forwards
        
        animationGroup.animations = [fadeIn, fadeOut]
        
        imageLayer.add(animationGroup, forKey: "image_overlay")
        
        return imageLayer
    }
    
    /// テキストオーバーレイレイヤーを作成
    private func createTextOverlayLayer(
        overlay: Overlay,
        text: String,
        style: TextOverlayStyle,
        videoSize: CGSize
    ) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.contentsScale = UIScreen.main.scale
        
        // フォント設定
        let fontSize = style.fontSize
        let fontName = style.fontName == "System" ? "Helvetica-Bold" : style.fontName
        
        if let font = CGFont(fontName as CFString) {
            textLayer.font = font
        }
        textLayer.fontSize = fontSize
        
        // テキスト設定
        textLayer.string = text
        textLayer.alignmentMode = .center
        textLayer.truncationMode = .none
        textLayer.isWrapped = true
        
        textLayer.foregroundColor = UIColor(
            red: style.fontColor.red,
            green: style.fontColor.green,
            blue: style.fontColor.blue,
            alpha: style.fontColor.alpha
        ).cgColor
        
        // 背景色設定
        if style.backgroundColor.alpha > 0 {
            textLayer.backgroundColor = UIColor(
                red: style.backgroundColor.red,
                green: style.backgroundColor.green,
                blue: style.backgroundColor.blue,
                alpha: style.backgroundColor.alpha
            ).cgColor
            textLayer.cornerRadius = 4
        }
        
        // レイヤーのサイズと位置
        let width = videoSize.width * overlay.size.width
        let height = videoSize.height * overlay.size.height
        let x = (videoSize.width * overlay.position.x) - (width / 2)
        let y = (videoSize.height * overlay.position.y) - (height / 2)
        
        textLayer.frame = CGRect(x: x, y: y, width: width, height: height)
        
        // 表示タイミング設定
        textLayer.opacity = 0
        
        // アニメーショングループを作成
        let animationGroup = CAAnimationGroup()
        animationGroup.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.startTime
        animationGroup.duration = overlay.endTime - overlay.startTime
        animationGroup.fillMode = .both
        animationGroup.isRemovedOnCompletion = false
        
        // フェードイン
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.3
        fadeIn.beginTime = 0
        fadeIn.fillMode = .forwards
        
        // フェードアウト
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = 0.3
        fadeOut.beginTime = max(0, animationGroup.duration - 0.3)
        fadeOut.fillMode = .forwards
        
        animationGroup.animations = [fadeIn, fadeOut]
        
        textLayer.add(animationGroup, forKey: "text_overlay")
        
        return textLayer
    }
    
    // MARK: - Helper Methods
    
    /// コンポジションをエクスポートする
    private func exportComposition(
        _ composition: AVMutableComposition,
        to outputURL: URL,
        videoComposition: AVVideoComposition? = nil,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 既存ファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(VideoEditorError.exportSessionCreationFailed))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        // 進捗監視
        if let progress = progress {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                let currentProgress = Double(exportSession.progress)
                progress(currentProgress)
                
                if currentProgress >= 1.0 || exportSession.status != .exporting {
                    timer.invalidate()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? VideoEditorError.exportFailed))
            case .cancelled:
                completion(.failure(VideoEditorError.exportCancelled))
            default:
                completion(.failure(VideoEditorError.exportFailed))
            }
        }
    }
}

// MARK: - Error Types

enum VideoEditorError: LocalizedError {
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

