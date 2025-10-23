//
//  SubtitleGenerationService.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import AVFoundation
import Speech

/// 字幕自動生成機能を提供するサービス
/// 注: Whisper統合は将来的に実装予定。現時点ではAppleのSpeech Frameworkを使用
class SubtitleGenerationService {
    
    // MARK: - Singleton
    static let shared = SubtitleGenerationService()
    private init() {}
    
    // MARK: - Speech Recognition
    
    /// 動画から音声を認識して字幕を生成する
    /// - Parameters:
    ///   - videoAsset: 元の動画アセット
    ///   - language: 認識言語（例: "ja-JP", "en-US"）
    ///   - progress: 進捗ハンドラ
    ///   - completion: 完了ハンドラ
    func generateSubtitles(
        from videoAsset: AVAsset,
        language: String = "ja-JP",
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<[Subtitle], Error>) -> Void
    ) {
        // 音声認識の権限チェック
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                completion(.failure(SubtitleGenerationError.authorizationDenied))
                return
            }
            
            // 音声を抽出
            self.extractAudioForRecognition(from: videoAsset) { result in
                switch result {
                case .success(let audioURL):
                    self.recognizeSpeech(
                        from: audioURL,
                        language: language,
                        progress: progress,
                        completion: completion
                    )
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 音声認識用に音声を抽出
    private func extractAudioForRecognition(
        from videoAsset: AVAsset,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        guard let exportSession = AVAssetExportSession(
            asset: videoAsset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            completion(.failure(SubtitleGenerationError.audioExtractionFailed))
            return
        }
        
        exportSession.outputURL = temporaryURL
        exportSession.outputFileType = .m4a
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(temporaryURL))
            case .failed:
                completion(.failure(exportSession.error ?? SubtitleGenerationError.audioExtractionFailed))
            case .cancelled:
                completion(.failure(SubtitleGenerationError.recognitionCancelled))
            default:
                completion(.failure(SubtitleGenerationError.audioExtractionFailed))
            }
        }
    }
    
    /// 音声認識を実行
    private func recognizeSpeech(
        from audioURL: URL,
        language: String,
        progress: ((Double) -> Void)?,
        completion: @escaping (Result<[Subtitle], Error>) -> Void
    ) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
              recognizer.isAvailable else {
            completion(.failure(SubtitleGenerationError.recognizerUnavailable))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = result, result.isFinal else {
                return
            }
            
            // 認識結果から字幕を生成
            let subtitles = self.createSubtitles(from: result)
            completion(.success(subtitles))
            
            // 一時ファイルを削除
            try? FileManager.default.removeItem(at: audioURL)
        }
    }
    
    /// 認識結果から字幕配列を作成
    private func createSubtitles(from result: SFSpeechRecognitionResult) -> [Subtitle] {
        var subtitles: [Subtitle] = []
        
        // セグメントごとに字幕を作成
        let segments = result.bestTranscription.segments
        
        for segment in segments {
            let startTime = segment.timestamp
            let duration = segment.duration
            let endTime = startTime + duration
            
            let subtitle = Subtitle(
                text: segment.substring,
                startTime: startTime,
                endTime: endTime
            )
            
            subtitles.append(subtitle)
        }
        
        // 短いセグメントを結合
        subtitles = mergeShortSubtitles(subtitles)
        
        return subtitles
    }
    
    /// 短い字幕を結合して読みやすくする
    private func mergeShortSubtitles(_ subtitles: [Subtitle], minDuration: TimeInterval = 2.0) -> [Subtitle] {
        var merged: [Subtitle] = []
        var currentSubtitle: Subtitle?
        
        for subtitle in subtitles {
            if let current = currentSubtitle {
                let duration = subtitle.endTime - current.startTime
                
                if duration < minDuration {
                    // 結合
                    let mergedText = current.text + " " + subtitle.text
                    currentSubtitle = Subtitle(
                        text: mergedText,
                        startTime: current.startTime,
                        endTime: subtitle.endTime
                    )
                } else {
                    // 現在の字幕を追加して新しい字幕を開始
                    merged.append(current)
                    currentSubtitle = subtitle
                }
            } else {
                currentSubtitle = subtitle
            }
        }
        
        if let current = currentSubtitle {
            merged.append(current)
        }
        
        return merged
    }
    
    // MARK: - Whisper Integration (Future Implementation)
    
    /// Whisperモデルを使用した字幕生成（将来実装）
    /// - Note: Whisper.cppなどのオフラインWhisper実装を統合予定
    func generateSubtitlesWithWhisper(
        from videoAsset: AVAsset,
        language: String = "ja",
        completion: @escaping (Result<[Subtitle], Error>) -> Void
    ) {
        // TODO: Whisper.cpp統合を実装
        // 1. 音声を抽出
        // 2. Whisperモデルで音声認識
        // 3. タイムスタンプ付きの字幕を生成
        completion(.failure(SubtitleGenerationError.whisperNotImplemented))
    }
}

// MARK: - Error Types

enum SubtitleGenerationError: LocalizedError {
    case authorizationDenied
    case audioExtractionFailed
    case recognizerUnavailable
    case recognitionCancelled
    case whisperNotImplemented
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "音声認識の権限が拒否されました"
        case .audioExtractionFailed:
            return "音声の抽出に失敗しました"
        case .recognizerUnavailable:
            return "音声認識が利用できません"
        case .recognitionCancelled:
            return "音声認識がキャンセルされました"
        case .whisperNotImplemented:
            return "Whisper統合は未実装です"
        }
    }
}

