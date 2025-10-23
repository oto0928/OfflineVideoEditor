//
//  InteractiveVideoPreview.swift
//  OfflineVideoEditor
//
//  Created by AI on 2025/10/23.
//

import SwiftUI
import AVKit

/// インタラクティブな動画プレビュー（ドラッグ可能なオーバーレイ付き）
struct InteractiveVideoPreview: View {
    
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedOverlayId: UUID?
    @State private var editMode: Bool = false
    
    var body: some View {
        ZStack {
            // 動画プレイヤー
            if let player = viewModel.getPlayer() {
                VideoPlayer(player: player)
                    .disabled(editMode)
            }
            
            // ドラッグ可能なオーバーレイレイヤー
            if editMode {
                GeometryReader { geometry in
                    ZStack {
                        // 半透明の編集モードオーバーレイ
                        Color.black.opacity(0.1)
                            .onTapGesture {
                                selectedOverlayId = nil
                            }
                        
                        // 字幕プレビュー
                        if let project = viewModel.currentProject {
                            ForEach(project.subtitles) { subtitle in
                                DraggableSubtitleView(
                                    subtitle: subtitle,
                                    containerSize: geometry.size,
                                    isSelected: selectedOverlayId == subtitle.id,
                                    onPositionChanged: { newPosition in
                                        updateSubtitlePosition(subtitle.id, newPosition: newPosition)
                                    },
                                    onSelect: {
                                        selectedOverlayId = subtitle.id
                                    }
                                )
                            }
                            
                            // 画像オーバーレイ
                            ForEach(project.overlays.filter { $0.type == .image }) { overlay in
                                DraggableImageOverlayView(
                                    overlay: overlay,
                                    containerSize: geometry.size,
                                    isSelected: selectedOverlayId == overlay.id,
                                    onPositionChanged: { newPosition in
                                        updateOverlayPosition(overlay.id, newPosition: newPosition)
                                    },
                                    onSelect: {
                                        selectedOverlayId = overlay.id
                                    }
                                )
                            }
                            
                            // テキストオーバーレイ
                            ForEach(project.overlays.filter { $0.type == .text }) { overlay in
                                DraggableTextOverlayView(
                                    overlay: overlay,
                                    containerSize: geometry.size,
                                    isSelected: selectedOverlayId == overlay.id,
                                    onPositionChanged: { newPosition in
                                        updateOverlayPosition(overlay.id, newPosition: newPosition)
                                    },
                                    onSelect: {
                                        selectedOverlayId = overlay.id
                                    }
                                )
                            }
                        }
                    }
                }
            }
            
            // 編集モード切替ボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        editMode.toggle()
                        if !editMode {
                            selectedOverlayId = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: editMode ? "hand.tap.fill" : "hand.tap")
                            Text(editMode ? "プレビュー" : "編集")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(editMode ? Color.blue : Color.gray.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
    
    private func updateSubtitlePosition(_ id: UUID, newPosition: CGPoint) {
        guard var project = viewModel.currentProject,
              let index = project.subtitles.firstIndex(where: { $0.id == id }) else { return }
        
        // 相対座標に変換（0.0〜1.0）
        let relativeY = Double(newPosition.y)
        
        // 位置に応じてプリセットを設定
        if relativeY < 0.25 {
            project.subtitles[index].position = .top
        } else if relativeY > 0.75 {
            project.subtitles[index].position = .bottom
        } else {
            project.subtitles[index].position = .center
        }
        
        viewModel.currentProject = project
    }
    
    private func updateOverlayPosition(_ id: UUID, newPosition: CGPoint) {
        guard var project = viewModel.currentProject,
              let index = project.overlays.firstIndex(where: { $0.id == id }) else { return }
        
        // 相対座標に変換（0.0〜1.0）
        project.overlays[index].position.x = Double(newPosition.x)
        project.overlays[index].position.y = Double(newPosition.y)
        
        viewModel.currentProject = project
    }
}

// MARK: - Draggable Subtitle View

struct DraggableSubtitleView: View {
    let subtitle: Subtitle
    let containerSize: CGSize
    let isSelected: Bool
    let onPositionChanged: (CGPoint) -> Void
    let onSelect: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack {
            Text(subtitle.text)
                .font(.system(size: CGFloat(subtitle.style.fontSize)))
                .foregroundColor(Color(
                    red: subtitle.style.fontColor.red,
                    green: subtitle.style.fontColor.green,
                    blue: subtitle.style.fontColor.blue,
                    opacity: subtitle.style.fontColor.alpha
                ))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Color(
                        red: subtitle.style.backgroundColor.red,
                        green: subtitle.style.backgroundColor.green,
                        blue: subtitle.style.backgroundColor.blue,
                        opacity: subtitle.style.backgroundColor.alpha
                    )
                )
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .position(calculatePosition())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let newPosition = CGPoint(
                        x: 0.5,
                        y: (calculatePosition().y + value.translation.height) / containerSize.height
                    )
                    onPositionChanged(newPosition)
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    private func calculatePosition() -> CGPoint {
        let baseY: CGFloat
        switch subtitle.position {
        case .top:
            baseY = containerSize.height * 0.15
        case .center:
            baseY = containerSize.height * 0.5
        case .bottom:
            baseY = containerSize.height * 0.85
        case .custom:
            baseY = containerSize.height * 0.85
        }
        
        return CGPoint(
            x: containerSize.width / 2 + dragOffset.width,
            y: baseY + dragOffset.height
        )
    }
}

// MARK: - Draggable Image Overlay View

struct DraggableImageOverlayView: View {
    let overlay: Overlay
    let containerSize: CGSize
    let isSelected: Bool
    let onPositionChanged: (CGPoint) -> Void
    let onSelect: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        Group {
            if let imageURL = overlay.imageURL,
               let uiImage = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: containerSize.width * CGFloat(overlay.size.width),
                        height: containerSize.height * CGFloat(overlay.size.height)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
            }
        }
        .position(calculatePosition())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let newPosition = CGPoint(
                        x: (calculatePosition().x + value.translation.width) / containerSize.width,
                        y: (calculatePosition().y + value.translation.height) / containerSize.height
                    )
                    onPositionChanged(newPosition)
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    private func calculatePosition() -> CGPoint {
        CGPoint(
            x: containerSize.width * CGFloat(overlay.position.x) + dragOffset.width,
            y: containerSize.height * CGFloat(overlay.position.y) + dragOffset.height
        )
    }
}

// MARK: - Draggable Text Overlay View

struct DraggableTextOverlayView: View {
    let overlay: Overlay
    let containerSize: CGSize
    let isSelected: Bool
    let onPositionChanged: (CGPoint) -> Void
    let onSelect: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        Group {
            if let text = overlay.text, let style = overlay.textStyle {
                Text(text)
                    .font(.system(size: CGFloat(style.fontSize)))
                    .foregroundColor(Color(
                        red: style.fontColor.red,
                        green: style.fontColor.green,
                        blue: style.fontColor.blue,
                        opacity: style.fontColor.alpha
                    ))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Color(
                            red: style.backgroundColor.red,
                            green: style.backgroundColor.green,
                            blue: style.backgroundColor.blue,
                            opacity: style.backgroundColor.alpha
                        )
                    )
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
            }
        }
        .frame(
            width: containerSize.width * CGFloat(overlay.size.width),
            height: containerSize.height * CGFloat(overlay.size.height)
        )
        .position(calculatePosition())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let newPosition = CGPoint(
                        x: (calculatePosition().x + value.translation.width) / containerSize.width,
                        y: (calculatePosition().y + value.translation.height) / containerSize.height
                    )
                    onPositionChanged(newPosition)
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    private func calculatePosition() -> CGPoint {
        CGPoint(
            x: containerSize.width * CGFloat(overlay.position.x) + dragOffset.width,
            y: containerSize.height * CGFloat(overlay.position.y) + dragOffset.height
        )
    }
}

