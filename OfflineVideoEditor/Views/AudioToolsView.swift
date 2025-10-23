//
//  AudioToolsView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI

/// 音声編集ツールのビュー
struct AudioToolsView: View {
    
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var volume: Double = 1.0
    @State private var fadeInDuration: Double = 0
    @State private var fadeOutDuration: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("音声編集")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // 音量調整
                VStack(alignment: .leading, spacing: 8) {
                    Text("音量: \(Int(volume * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Slider(value: $volume, in: 0...2, step: 0.1)
                        .accentColor(.blue)
                }
                .padding(.horizontal)
                
                // フェードイン/アウト
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("フェードイン: \(String(format: "%.1fs", fadeInDuration))")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Slider(value: $fadeInDuration, in: 0...5, step: 0.5)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("フェードアウト: \(String(format: "%.1fs", fadeOutDuration))")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Slider(value: $fadeOutDuration, in: 0...5, step: 0.5)
                            .accentColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // BGM追加ボタン
                Button(action: {
                    // BGM追加機能
                }) {
                    HStack {
                        Image(systemName: "music.note")
                        Text("BGMを追加")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.bottom, 8)
            }
            .padding()
        }
    }
}

