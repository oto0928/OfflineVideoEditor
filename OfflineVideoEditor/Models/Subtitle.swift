//
//  Subtitle.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import SwiftUI

/// 字幕データを表すモデル
struct Subtitle: Identifiable, Codable {
    let id: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var position: SubtitlePosition
    var style: SubtitleStyle
    
    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        position: SubtitlePosition = .bottom,
        style: SubtitleStyle = SubtitleStyle()
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.position = position
        self.style = style
    }
}

/// 字幕の位置
enum SubtitlePosition: String, Codable {
    case top
    case center
    case bottom
    case custom
}

/// Codable対応のテキストアラインメント
enum SubtitleTextAlignment: String, Codable {
    case leading
    case center
    case trailing
}

/// 字幕のスタイル
struct SubtitleStyle: Codable {
    var fontName: String
    var fontSize: CGFloat
    var fontColor: CodableColor
    var backgroundColor: CodableColor
    var opacity: Double
    var alignment: SubtitleTextAlignment
    var strokeColor: CodableColor?
    var strokeWidth: CGFloat
    
    init(
        fontName: String = "System",
        fontSize: CGFloat = 24,
        fontColor: CodableColor = CodableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        backgroundColor: CodableColor = CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5),
        opacity: Double = 1.0,
        alignment: SubtitleTextAlignment = .center,
        strokeColor: CodableColor? = nil,
        strokeWidth: CGFloat = 0
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.backgroundColor = backgroundColor
        self.opacity = opacity
        self.alignment = alignment
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }
}

/// CodableなColor型
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    // 便利なstaticプロパティ
    static var white: CodableColor {
        CodableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    }
    
    static var black: CodableColor {
        CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    
    static var clear: CodableColor {
        CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    }
    
    // Colorから作成するためのヘルパーメソッド（UIで使用）
    static func from(_ color: Color) -> CodableColor {
        // デフォルトは白
        // 注: SwiftUIのColorから直接RGBA値を取得するのは複雑なため、
        // UIでは明示的にRGBA値を指定することを推奨
        return .white
    }
}

