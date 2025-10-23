//
//  ExportToolsView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI

/// エクスポートツールのビュー
struct ExportToolsView: View {
    
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedResolution: VideoResolution = .hd1080
    @State private var selectedFrameRate: Double = 30.0
    @State private var selectedAspectRatio: AspectRatio = .aspect16_9
    @State private var selectedQuality: ExportService.ExportQuality = .high
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("エクスポート設定")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                
                // 解像度とフレームレート
                VStack(spacing: 12) {
                    // 解像度選択
                    HStack {
                        Text("解像度")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Picker("解像度", selection: $selectedResolution) {
                            ForEach(VideoResolution.allCases, id: \.self) { resolution in
                                Text(resolution.rawValue).tag(resolution)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // フレームレート選択
                    HStack {
                        Text("フレームレート")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Picker("FPS", selection: $selectedFrameRate) {
                            Text("24 fps").tag(24.0)
                            Text("30 fps").tag(30.0)
                            Text("60 fps").tag(60.0)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                
                // アスペクト比と品質
                VStack(spacing: 12) {
                    // アスペクト比選択
                    HStack {
                        Text("アスペクト比")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Picker("アスペクト比", selection: $selectedAspectRatio) {
                            ForEach(AspectRatio.allCases, id: \.self) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // 品質選択
                    HStack {
                        Text("品質")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Picker("品質", selection: $selectedQuality) {
                            Text("低").tag(ExportService.ExportQuality.low)
                            Text("中").tag(ExportService.ExportQuality.medium)
                            Text("高").tag(ExportService.ExportQuality.high)
                            Text("最高").tag(ExportService.ExportQuality.highest)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                
                // エクスポートボタン
                Button(action: {
                    let settings = ExportService.ExportSettings(
                        resolution: selectedResolution,
                        frameRate: selectedFrameRate,
                        aspectRatio: selectedAspectRatio,
                        quality: selectedQuality
                    )
                    
                    let outputURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("export_\(UUID().uuidString)")
                        .appendingPathExtension("mp4")
                    
                    viewModel.exportProject(settings: settings, outputURL: outputURL)
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        Text("動画をエクスポート")
                            .font(.body)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

