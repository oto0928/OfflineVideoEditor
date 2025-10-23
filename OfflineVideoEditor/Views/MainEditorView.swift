//
//  MainEditorView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI
import AVKit

/// メインの編集画面
struct MainEditorView: View {
    
    @StateObject private var viewModel = VideoEditorViewModel()
    @State private var selectedTab: EditorTab = .edit
    @State private var showImportPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // プレビュー画面（上部中央）
            videoPreviewSection
            
            // ツールパネル（下部）
            toolPanelSection
            
            // タブナビゲーション（最下部）
            tabNavigationSection
        }
        .background(Color.black)
        .ignoresSafeArea()
        .sheet(isPresented: $showImportPicker) {
            // 動画インポート画面
            VideoImportView { url in
                viewModel.loadVideo(from: url)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingView(progress: viewModel.exportProgress)
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var videoPreviewSection: some View {
        VStack {
            if viewModel.currentProject?.videoURL != nil {
                InteractiveVideoPreview(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("動画を読み込んでください")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                showImportPicker = true
            }) {
                Text("動画を選択")
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Tool Panel Section
    
    private var toolPanelSection: some View {
        VStack(spacing: 0) {
            // 選択されたツールに応じた編集オプションを表示
            switch selectedTab {
            case .edit:
                EditToolsView(viewModel: viewModel)
            case .subtitle:
                SubtitleToolsView(viewModel: viewModel)
            case .audio:
                AudioToolsView(viewModel: viewModel)
            case .effect:
                EffectToolsView(viewModel: viewModel)
            case .export:
                ExportToolsView(viewModel: viewModel)
            }
        }
        .frame(height: 380)
        .background(Color.gray.opacity(0.2))
    }
    
    // MARK: - Tab Navigation Section
    
    private var tabNavigationSection: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .frame(height: 60)
        .background(Color.black)
    }
}

// MARK: - Editor Tab

enum EditorTab: String, CaseIterable {
    case edit = "編集"
    case subtitle = "字幕"
    case audio = "音声"
    case effect = "エフェクト"
    case export = "エクスポート"
    
    var icon: String {
        switch self {
        case .edit:
            return "scissors"
        case .subtitle:
            return "captions.bubble"
        case .audio:
            return "waveform"
        case .effect:
            return "wand.and.stars"
        case .export:
            return "square.and.arrow.up"
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: EditorTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                
                Text(tab.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                if progress > 0 {
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding(32)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

#Preview {
    MainEditorView()
}

