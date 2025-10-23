//
//  EffectToolsView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI
import PhotosUI

/// エフェクトツールのビュー（画像・テキストオーバーレイ）
struct EffectToolsView: View {
    
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var showImagePicker = false
    @State private var showTextEditor = false
    @State private var showOverlayList = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("画像・テキスト追加")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                
                // 画像追加ボタン
                Button(action: {
                    showImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                        Text("画像を追加")
                            .font(.body)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                
                // テキスト追加ボタン
                Button(action: {
                    showTextEditor = true
                }) {
                    HStack {
                        Image(systemName: "textformat")
                            .font(.system(size: 18))
                        Text("テキストを追加")
                            .font(.body)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                
                // オーバーレイリスト
                if let project = viewModel.currentProject,
                   !project.overlays.isEmpty {
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("追加済み (\(project.overlays.count))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        ForEach(project.overlays) { overlay in
                            OverlayItemCard(
                                overlay: overlay,
                                onEdit: {
                                    // 編集処理
                                },
                                onDelete: {
                                    viewModel.deleteOverlay(id: overlay.id)
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                        
                        // オーバーレイを動画に適用ボタン
                        Button(action: {
                            viewModel.applyOverlaysToVideo()
                        }) {
                            HStack {
                                Image(systemName: "video.badge.checkmark")
                                    .font(.system(size: 18))
                                Text("動画に適用")
                                    .font(.body)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { url in
                viewModel.addImageOverlay(imageURL: url)
            }
        }
        .sheet(isPresented: $showTextEditor) {
            if viewModel.currentProject != nil {
                TextOverlayEditorView(
                    videoDuration: viewModel.currentProject?.duration ?? 0,
                    onAdd: { overlay in
                        viewModel.addTextOverlay(overlay: overlay)
                    }
                )
            }
        }
    }
}

/// オーバーレイアイテムカード
struct OverlayItemCard: View {
    let overlay: Overlay
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: overlay.type == .image ? "photo" : "textformat")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(overlay.type.rawValue)
                    .font(.body)
                        .foregroundColor(.white)
                    
                if overlay.type == .text, let text = overlay.text {
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Text("\(formatTime(overlay.startTime)) - \(formatTime(overlay.endTime))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 画像ピッカー

struct ImagePickerView: View {
    let onImageSelected: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("画像を選択")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            // 一時ファイルとして保存
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("png")
                            
                            if let pngData = image.pngData() {
                                try? pngData.write(to: tempURL)
                                onImageSelected(tempURL)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("画像を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - テキストオーバーレイ編集

struct TextOverlayEditorView: View {
    let videoDuration: TimeInterval
    let onAdd: (Overlay) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var startTime: Double = 0
    @State private var endTime: Double = 5
    @State private var fontSize: Double = 36
    @State private var selectedColor: ColorOption = .white
    @State private var selectedBackgroundColor: ColorOption = .clear
    @State private var positionX: Double = 0.5
    @State private var positionY: Double = 0.5
    
    var body: some View {
        NavigationView {
            Form {
                Section("テキスト") {
                    TextEditor(text: $text)
                        .frame(height: 100)
                }
                
                Section("表示時間") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("開始: \(formatTime(startTime))")
                            .font(.subheadline)
                        Slider(value: $startTime, in: 0...videoDuration, step: 0.1)
                            .accentColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("終了: \(formatTime(endTime))")
                            .font(.subheadline)
                        Slider(value: $endTime, in: 0...videoDuration, step: 0.1)
                            .accentColor(.red)
                    }
                }
                
                Section("スタイル") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("フォントサイズ: \(Int(fontSize))")
                            Spacer()
                        }
                        Slider(value: $fontSize, in: 12...72, step: 1)
                    }
                    
                    Picker("文字色", selection: $selectedColor) {
                        ForEach(ColorOption.allCases, id: \.self) { option in
                            HStack {
                                Circle()
                                    .fill(option.codableColor.color)
                                    .frame(width: 20, height: 20)
                                Text(option.rawValue)
                            }
                            .tag(option)
                        }
                    }
                    
                    Picker("背景色", selection: $selectedBackgroundColor) {
                        ForEach(ColorOption.allCases, id: \.self) { option in
                            HStack {
                                Circle()
                                    .fill(option.codableColor.color)
                                    .frame(width: 20, height: 20)
                                Text(option.rawValue)
                            }
                            .tag(option)
                        }
                    }
                }
                
                Section("位置") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("横位置: \(Int(positionX * 100))%")
                            Spacer()
                        }
                        Slider(value: $positionX, in: 0...1, step: 0.01)
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("縦位置: \(Int(positionY * 100))%")
                            Spacer()
                        }
                        Slider(value: $positionY, in: 0...1, step: 0.01)
                    }
                }
                
                Section {
                    Button("追加") {
                        addTextOverlay()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .disabled(text.isEmpty)
                }
            }
            .navigationTitle("テキスト追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addTextOverlay() {
        let textStyle = TextOverlayStyle(
            fontName: "System",
            fontSize: fontSize,
            fontColor: selectedColor.codableColor,
            backgroundColor: selectedBackgroundColor.codableColor,
            alignment: .center
        )
        
        var overlay = Overlay(
            type: .text,
            startTime: startTime,
            endTime: endTime,
            position: OverlayPosition(x: positionX, y: positionY),
            size: OverlaySize(width: 0.8, height: 0.2)
        )
        overlay.text = text
        overlay.textStyle = textStyle
        
        onAdd(overlay)
        dismiss()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

