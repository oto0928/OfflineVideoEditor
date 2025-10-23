//
//  AudioTrack.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation

/// 音声トラックを表すモデル
struct AudioTrack: Identifiable, Codable {
    let id: UUID
    var name: String
    var audioURL: URL?
    var startTime: TimeInterval
    var duration: TimeInterval
    var volume: Float
    var fadeIn: TimeInterval
    var fadeOut: TimeInterval
    var type: AudioTrackType
    
    init(
        id: UUID = UUID(),
        name: String,
        audioURL: URL? = nil,
        startTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        volume: Float = 1.0,
        fadeIn: TimeInterval = 0,
        fadeOut: TimeInterval = 0,
        type: AudioTrackType = .music
    ) {
        self.id = id
        self.name = name
        self.audioURL = audioURL
        self.startTime = startTime
        self.duration = duration
        self.volume = volume
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.type = type
    }
}

/// 音声トラックの種類
enum AudioTrackType: String, Codable {
    case original = "Original Audio"
    case music = "Background Music"
    case soundEffect = "Sound Effect"
    case narration = "Narration"
    case voiceOver = "Voice Over"
}

