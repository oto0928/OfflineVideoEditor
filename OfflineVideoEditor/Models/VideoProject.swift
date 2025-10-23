//
//  VideoProject.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import AVFoundation

/// 動画プロジェクト全体を表すモデル
struct VideoProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var videoURL: URL?
    var duration: TimeInterval
    var resolution: VideoResolution
    var frameRate: Double
    var aspectRatio: AspectRatio
    var subtitles: [Subtitle]
    var audioTracks: [AudioTrack]
    var effects: [Effect]
    var timelineItems: [TimelineItem]
    var overlays: [Overlay]
    
    init(
        id: UUID = UUID(),
        name: String = "New Project",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        videoURL: URL? = nil,
        duration: TimeInterval = 0,
        resolution: VideoResolution = .hd1080,
        frameRate: Double = 30.0,
        aspectRatio: AspectRatio = .aspect16_9,
        subtitles: [Subtitle] = [],
        audioTracks: [AudioTrack] = [],
        effects: [Effect] = [],
        timelineItems: [TimelineItem] = [],
        overlays: [Overlay] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.videoURL = videoURL
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.aspectRatio = aspectRatio
        self.subtitles = subtitles
        self.audioTracks = audioTracks
        self.effects = effects
        self.timelineItems = timelineItems
        self.overlays = overlays
    }
}

/// 動画の解像度
enum VideoResolution: String, Codable, CaseIterable {
    case sd480 = "480p"
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"
    
    var size: CGSize {
        switch self {
        case .sd480:
            return CGSize(width: 854, height: 480)
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .uhd4k:
            return CGSize(width: 3840, height: 2160)
        }
    }
}

/// アスペクト比
enum AspectRatio: String, Codable, CaseIterable {
    case aspect16_9 = "16:9"
    case aspect9_16 = "9:16"
    case aspect1_1 = "1:1"
    case aspect4_3 = "4:3"
    case aspect21_9 = "21:9"
    
    var ratio: CGFloat {
        switch self {
        case .aspect16_9:
            return 16.0 / 9.0
        case .aspect9_16:
            return 9.0 / 16.0
        case .aspect1_1:
            return 1.0
        case .aspect4_3:
            return 4.0 / 3.0
        case .aspect21_9:
            return 21.0 / 9.0
        }
    }
}

