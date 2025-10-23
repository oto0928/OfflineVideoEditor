//
//  Effect.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation

/// ビジュアルエフェクトを表すモデル
struct Effect: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: EffectType
    var startTime: TimeInterval
    var endTime: TimeInterval
    var intensity: Double
    var parameters: [String: EffectParameter]
    
    init(
        id: UUID = UUID(),
        name: String,
        type: EffectType,
        startTime: TimeInterval,
        endTime: TimeInterval,
        intensity: Double = 1.0,
        parameters: [String: EffectParameter] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.intensity = intensity
        self.parameters = parameters
    }
}

/// エフェクトのタイプ
enum EffectType: String, Codable, CaseIterable {
    // フィルター
    case brightness = "Brightness"
    case contrast = "Contrast"
    case saturation = "Saturation"
    case sepia = "Sepia"
    case vintage = "Vintage"
    case blackAndWhite = "Black & White"
    
    // ブラー
    case blur = "Blur"
    case gaussianBlur = "Gaussian Blur"
    case motionBlur = "Motion Blur"
    
    // その他
    case glitch = "Glitch"
    case vignette = "Vignette"
    case sharpen = "Sharpen"
    
    // トランジション
    case fade = "Fade"
    case dissolve = "Dissolve"
    case wipe = "Wipe"
    case slide = "Slide"
}

/// エフェクトのパラメータ
enum EffectParameter: Codable {
    case double(Double)
    case int(Int)
    case string(String)
    case bool(Bool)
}

