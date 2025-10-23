//
//  VideoImportView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI
import PhotosUI
import AVFoundation

/// 動画インポート画面
struct VideoImportView: View {
    
    @Environment(\.dismiss) private var dismiss
    let onVideoSelected: (URL) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("動画を読み込み中...")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "video.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("動画を選択してください")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("フォトライブラリから選択")
                        }
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            await loadVideo(from: newItem)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("動画を読み込む")
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
    
    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // まずData型で読み込んでみる
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    errorMessage = "動画データの読み込みに失敗しました"
                    isLoading = false
                }
                return
            }
            
            // 一時ファイルに保存
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            try data.write(to: tempURL)
            
            // 動画が有効か確認
            let asset = AVAsset(url: tempURL)
            let isPlayable = try await asset.load(.isPlayable)
            
            if isPlayable {
                await MainActor.run {
                    print("✅ 動画を読み込みました: \(tempURL)")
                    onVideoSelected(tempURL)
                    dismiss()
                }
            } else {
                await MainActor.run {
                    errorMessage = "この動画は再生できません"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "エラー: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ 動画の読み込みエラー: \(error)")
        }
    }
}

