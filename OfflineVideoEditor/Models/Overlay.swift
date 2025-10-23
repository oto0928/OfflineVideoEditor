//
//  Overlay.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import Foundation
import SwiftUI

/// オーバーレイの種類
enum OverlayType: String, Codable {
    case image = "画像"
    case text = "テキスト"
}

/// オーバーレイデータを表すモデル
struct Overlay: Identifiable, Codable {
    let id: UUID
    var type: OverlayType
    var startTime: TimeInterval
    var endTime: TimeInterval
    var position: OverlayPosition
    var size: OverlaySize
    
    // 画像用
    var imageURL: URL?
    
    // テキスト用
    var text: String?
    var textStyle: TextOverlayStyle?
    
    init(
        id: UUID = UUID(),
        type: OverlayType,
        startTime: TimeInterval,
        endTime: TimeInterval,
        position: OverlayPosition = OverlayPosition(),
        size: OverlaySize = OverlaySize()
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.position = position
        self.size = size
    }
}

/// オーバーレイの位置
struct OverlayPosition: Codable {
    var x: CGFloat // 0.0 〜 1.0 (画面幅の割合)
    var y: CGFloat // 0.0 〜 1.0 (画面高さの割合)
    
    init(x: CGFloat = 0.5, y: CGFloat = 0.5) {
        self.x = x
        self.y = y
    }
}

/// オーバーレイのサイズ
struct OverlaySize: Codable {
    var width: CGFloat  // 0.0 〜 1.0 (画面幅の割合)
    var height: CGFloat // 0.0 〜 1.0 (画面高さの割合)
    
    init(width: CGFloat = 0.3, height: CGFloat = 0.3) {
        self.width = width
        self.height = height
    }
}

/// テキストオーバーレイのスタイル
struct TextOverlayStyle: Codable {
    var fontName: String
    var fontSize: CGFloat
    var fontColor: CodableColor
    var backgroundColor: CodableColor
    var alignment: SubtitleTextAlignment
    var strokeColor: CodableColor?
    var strokeWidth: CGFloat
    
    init(
        fontName: String = "System",
        fontSize: CGFloat = 36,
        fontColor: CodableColor = CodableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        backgroundColor: CodableColor = CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        alignment: SubtitleTextAlignment = .center,
        strokeColor: CodableColor? = nil,
        strokeWidth: CGFloat = 0
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.backgroundColor = backgroundColor
        self.alignment = alignment
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }
}

