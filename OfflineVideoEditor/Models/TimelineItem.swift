//
//  TimelineItem.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation

/// タイムライン上のアイテムを表すモデル
struct TimelineItem: Identifiable, Codable {
    let id: UUID
    var type: TimelineItemType
    var startTime: TimeInterval
    var duration: TimeInterval
    var layer: Int
    
    init(
        id: UUID = UUID(),
        type: TimelineItemType,
        startTime: TimeInterval,
        duration: TimeInterval,
        layer: Int = 0
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.duration = duration
        self.layer = layer
    }
    
    var endTime: TimeInterval {
        return startTime + duration
    }
}

/// タイムラインアイテムの種類
enum TimelineItemType: Codable {
    case video(VideoClip)
    case audio(AudioTrack)
    case subtitle(Subtitle)
    case effect(Effect)
    case image(ImageOverlay)
    case text(TextOverlay)
}

/// 動画クリップ
struct VideoClip: Codable {
    var url: URL
    var trimStart: TimeInterval
    var trimEnd: TimeInterval
    var speed: Double
    var volume: Float
    
    init(
        url: URL,
        trimStart: TimeInterval = 0,
        trimEnd: TimeInterval = 0,
        speed: Double = 1.0,
        volume: Float = 1.0
    ) {
        self.url = url
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.speed = speed
        self.volume = volume
    }
}

/// 画像オーバーレイ
struct ImageOverlay: Codable {
    var imageURL: URL
    var position: CGPoint
    var size: CGSize
    var opacity: Double
    
    init(
        imageURL: URL,
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 100, height: 100),
        opacity: Double = 1.0
    ) {
        self.imageURL = imageURL
        self.position = position
        self.size = size
        self.opacity = opacity
    }
}

/// テキストオーバーレイ
struct TextOverlay: Codable {
    var text: String
    var position: CGPoint
    var style: SubtitleStyle
    var animation: TextAnimation?
    
    init(
        text: String,
        position: CGPoint = .zero,
        style: SubtitleStyle = SubtitleStyle(),
        animation: TextAnimation? = nil
    ) {
        self.text = text
        self.position = position
        self.style = style
        self.animation = animation
    }
}

/// テキストアニメーション
enum TextAnimation: String, Codable {
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case slideIn = "Slide In"
    case slideOut = "Slide Out"
    case typewriter = "Typewriter"
    case bounce = "Bounce"
}

