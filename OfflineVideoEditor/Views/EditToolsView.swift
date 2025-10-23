//
//  EditToolsView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI
import AVFoundation

/// 基本編集ツールのビュー
struct EditToolsView: View {
    
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedTool: EditTool = .trim
    
    var body: some View {
        VStack(spacing: 0) {
            // ツール選択バー
            toolSelectionBar
            
            Divider()
            
            // 選択されたツールのUI
            toolContentView
        }
    }
    
    private var toolSelectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EditTool.allCases, id: \.self) { tool in
                    ToolButton(
                        title: tool.rawValue,
                        icon: tool.icon,
                        isSelected: selectedTool == tool
                    ) {
                        selectedTool = tool
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 60)
        .background(Color.gray.opacity(0.1))
    }
    
    private var toolContentView: some View {
        Group {
            switch selectedTool {
            case .trim:
                TrimControlView(viewModel: viewModel)
            case .merge:
                MergeControlView(viewModel: viewModel)
            case .resize:
                ResizeControlView(viewModel: viewModel)
            case .speed:
                SpeedControlView(viewModel: viewModel)
            case .rotate:
                RotateControlView(viewModel: viewModel)
            case .crop:
                CropControlView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

enum EditTool: String, CaseIterable {
    case trim = "トリミング"
    case merge = "結合"
    case resize = "サイズ変更"
    case speed = "速度変更"
    case rotate = "回転"
    case crop = "クロップ"
    
    var icon: String {
        switch self {
        case .trim:
            return "scissors"
        case .merge:
            return "plus.rectangle.on.rectangle"
        case .resize:
            return "arrow.up.left.and.arrow.down.right"
        case .speed:
            return "gauge"
        case .rotate:
            return "rotate.right"
        case .crop:
            return "crop"
        }
    }
}

struct ToolButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
    }
}

// MARK: - Control Views

// トリミング範囲を表すデータ構造
struct TrimRange: Identifiable {
    let id = UUID()
    var startTime: Double
    var endTime: Double
}

struct TrimControlView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var trimRanges: [TrimRange] = []
    @State private var selectedRangeId: UUID?
    @State private var isDraggingStart: Bool = false
    @State private var isDraggingEnd: Bool = false
    @State private var thumbnails: [UIImage] = []
    @State private var isLoadingThumbnails: Bool = false
    @State private var currentPlaybackTime: Double = 0
    
    private var videoDuration: Double {
        viewModel.currentProject?.duration ?? 10.0
    }
    
    private var selectedRange: TrimRange? {
        trimRanges.first { $0.id == selectedRangeId }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // タイトルと追加ボタン
            HStack {
                Text("複数範囲トリミング")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 範囲を追加ボタン
                Button(action: {
                    addNewRange()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("追加")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            
            // タイムライン
            timelineSection
            
            // 範囲リスト
            rangeListSection
            
            // トリミング実行ボタン
            Button(action: {
                applyMultipleTrim()
            }) {
                HStack {
                    Image(systemName: "scissors")
                        .font(.system(size: 18))
                    Text("選択範囲を結合してトリミング")
                        .font(.body)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimRanges.isEmpty)
        }
        .padding()
        .onAppear {
            loadVideoThumbnails()
            // 初期範囲を追加
            if trimRanges.isEmpty {
                addNewRange()
            }
        }
    }
    
    // MARK: - Timeline Section
    
    private var timelineSection: some View {
        VStack(spacing: 8) {
            // タイムライン本体
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // サムネイル背景
                    if !thumbnails.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(thumbnails.indices, id: \.self) { index in
                                Image(uiImage: thumbnails[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(
                                        width: geometry.size.width / CGFloat(thumbnails.count),
                                        height: 60
                                    )
                                    .clipped()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 60)
                        
                        if isLoadingThumbnails {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    
                    // 全体を暗くする（選択範囲以外）
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 60)
                    
                    // 各選択範囲を表示
                    ForEach(trimRanges) { range in
                        let startPos = range.startTime / videoDuration * geometry.size.width
                        let endPos = range.endTime / videoDuration * geometry.size.width
                        let isSelected = range.id == selectedRangeId
                        
                        // 選択範囲（明るく表示）
                        Rectangle()
                            .fill(Color.clear)
                            .frame(
                                width: max(0, endPos - startPos),
                                height: 60
                            )
                            .background(
                                Rectangle()
                                    .fill(Color.clear)
                                    .background(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isSelected ? Color.blue : Color.green, lineWidth: isSelected ? 3 : 2)
                            )
                            .offset(x: startPos)
                            .onTapGesture {
                                selectedRangeId = range.id
                            }
                        
                        // 範囲番号表示
                        if let index = trimRanges.firstIndex(where: { $0.id == range.id }) {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                                .padding(4)
                                .background(isSelected ? Color.blue : Color.green)
                                .clipShape(Circle())
                                .position(x: (startPos + endPos) / 2, y: 30)
                        }
                    }
                    
                    // 現在の再生位置
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 60)
                        .offset(x: viewModel.currentTime / videoDuration * geometry.size.width - 1.5)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    
                    // 選択中の範囲のマーカー
                    if let range = selectedRange {
                        let startPos = range.startTime / videoDuration * geometry.size.width
                        let endPos = range.endTime / videoDuration * geometry.size.width
                        
                        // 開始マーカー
                        MultiRangeMarker(
                            label: "開始",
                            color: .green,
                            isDragging: $isDraggingStart
                        )
                        .position(x: startPos, y: 30)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingStart = true
                                    updateSelectedRangeStart(value.location.x / geometry.size.width * videoDuration)
                                }
                                .onEnded { _ in
                                    isDraggingStart = false
                                }
                        )
                        
                        // 終了マーカー
                        MultiRangeMarker(
                            label: "終了",
                            color: .red,
                            isDragging: $isDraggingEnd
                        )
                        .position(x: endPos, y: 30)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingEnd = true
                                    updateSelectedRangeEnd(value.location.x / geometry.size.width * videoDuration)
                                }
                                .onEnded { _ in
                                    isDraggingEnd = false
                                }
                        )
                    }
                }
            }
            .frame(height: 60)
            
            // タイムラインの目盛り
            HStack {
                Text(formatTime(0))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(formatTime(videoDuration / 2))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(formatTime(videoDuration))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 4)
            }
            .padding(.horizontal)
    }
    
    // MARK: - Range List Section
    
    private var rangeListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("選択範囲")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(trimRanges.indices, id: \.self) { index in
                        let range = trimRanges[index]
                        let isSelected = range.id == selectedRangeId
                        
                        HStack {
                            // 範囲番号
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(isSelected ? Color.blue : Color.green)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(formatTime(range.startTime)) - \(formatTime(range.endTime))")
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Text("長さ: \(formatTime(range.endTime - range.startTime))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // 削除ボタン
                            Button(action: {
                                deleteRange(id: range.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(8)
                            }
                        }
                        .padding()
                        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedRangeId = range.id
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    // MARK: - Range Management
    
    private func addNewRange() {
        // 既存の範囲と重ならない位置を探す
        var startTime = 0.0
        let defaultDuration = min(5.0, videoDuration / 4)
        
        // 最後の範囲の終了時間以降から開始
        if let lastRange = trimRanges.sorted(by: { $0.startTime < $1.startTime }).last {
            startTime = min(lastRange.endTime + 1.0, videoDuration - defaultDuration)
        }
        
        let endTime = min(startTime + defaultDuration, videoDuration)
        
        if startTime < videoDuration {
            let newRange = TrimRange(startTime: startTime, endTime: endTime)
            trimRanges.append(newRange)
            selectedRangeId = newRange.id
        }
    }
    
    private func deleteRange(id: UUID) {
        trimRanges.removeAll { $0.id == id }
        if selectedRangeId == id {
            selectedRangeId = trimRanges.first?.id
        }
        if trimRanges.isEmpty {
            addNewRange()
        }
    }
    
    private func updateSelectedRangeStart(_ newTime: Double) {
        guard let index = trimRanges.firstIndex(where: { $0.id == selectedRangeId }) else { return }
        let range = trimRanges[index]
        trimRanges[index].startTime = max(0, min(newTime, range.endTime - 0.1))
    }
    
    private func updateSelectedRangeEnd(_ newTime: Double) {
        guard let index = trimRanges.firstIndex(where: { $0.id == selectedRangeId }) else { return }
        let range = trimRanges[index]
        trimRanges[index].endTime = min(videoDuration, max(newTime, range.startTime + 0.1))
    }
    
    private func setCurrentTimeAsStart() {
        guard let index = trimRanges.firstIndex(where: { $0.id == selectedRangeId }) else { return }
        let range = trimRanges[index]
        trimRanges[index].startTime = max(0, min(viewModel.currentTime, range.endTime - 0.1))
    }
    
    private func setCurrentTimeAsEnd() {
        guard let index = trimRanges.firstIndex(where: { $0.id == selectedRangeId }) else { return }
        let range = trimRanges[index]
        trimRanges[index].endTime = min(videoDuration, max(viewModel.currentTime, range.startTime + 0.1))
    }
    
    private func applyMultipleTrim() {
        // 範囲を時間順にソート
        let sortedRanges = trimRanges.sorted { $0.startTime < $1.startTime }
        viewModel.trimMultipleRanges(ranges: sortedRanges.map { ($0.startTime, $0.endTime) })
    }
    
    // MARK: - Thumbnail Generation
    
    private func loadVideoThumbnails() {
        guard let videoURL = viewModel.currentProject?.videoURL else { return }
        
        isLoadingThumbnails = true
        
        Task {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 120, height: 60)
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                // 10個のサムネイルを生成
                let thumbnailCount = 10
                var generatedThumbnails: [UIImage] = []
                
                for i in 0..<thumbnailCount {
                    let time = CMTime(seconds: (durationSeconds / Double(thumbnailCount)) * Double(i), preferredTimescale: 600)
                    
                    do {
                        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        generatedThumbnails.append(image)
                    } catch {
                        print("サムネイル生成エラー: \(error)")
                    }
                }
                
                await MainActor.run {
                    self.thumbnails = generatedThumbnails
                    self.isLoadingThumbnails = false
                }
            } catch {
                print("動画読み込みエラー: \(error)")
                await MainActor.run {
                    self.isLoadingThumbnails = false
                }
            }
        }
    }
}

// MARK: - Timeline Marker

struct TimelineMarker: View {
    let time: Double
    let color: Color
    let label: String
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // ラベル
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .cornerRadius(4)
            
            Spacer()
                .frame(height: 4)
            
            // マーカーライン
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 40)
            
            // ドラッグハンドル
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .scaleEffect(isDragging ? 1.3 : 1.0)
                .animation(.spring(response: 0.3), value: isDragging)
        }
        .frame(width: 3)
    }
}

// MARK: - Multi Range Marker

struct MultiRangeMarker: View {
    let label: String
    let color: Color
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // ラベル
            Text(label)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(4)
            
            Spacer()
                .frame(height: 2)
            
            // マーカーライン
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 40)
            
            // ドラッグハンドル
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 2)
                .scaleEffect(isDragging ? 1.4 : 1.0)
                .animation(.spring(response: 0.3), value: isDragging)
        }
        .frame(width: 4)
    }
}

struct MergeControlView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedVideos: [URL] = []
    @State private var showVideoPicker = false
    @State private var videoItems: [VideoItem] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("動画を結合")
                .font(.headline)
                .foregroundColor(.white)
                
                Text("複数の動画を1つの動画に結合します")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // 現在のプロジェクト動画
                if let currentProject = viewModel.currentProject, currentProject.videoURL != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("現在の動画")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        VideoItemCard(
                            title: "メイン動画",
                            duration: currentProject.duration,
                            isMain: true
                        )
                    }
                    .padding(.horizontal)
                }
                
                // 追加された動画リスト
                if !videoItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("結合する動画 (\(videoItems.count))")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        ForEach(videoItems.indices, id: \.self) { index in
                            HStack {
                                VideoItemCard(
                                    title: "動画 \(index + 1)",
                                    duration: videoItems[index].duration,
                                    isMain: false
                                )
                                
                                Button(action: {
                                    videoItems.remove(at: index)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .padding(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 動画追加ボタン
                Button(action: {
                    showVideoPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("動画を追加")
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // 結合実行ボタン
                if !videoItems.isEmpty {
                    Button("結合を実行") {
                        mergeVideos()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoImportView { url in
                addVideo(url: url)
            }
        }
    }
    
    private func addVideo(url: URL) {
        let asset = AVAsset(url: url)
        Task { @MainActor in
            do {
                let duration = try await asset.load(.duration)
                videoItems.append(VideoItem(url: url, duration: duration.seconds))
            } catch {
                print("動画の読み込みエラー: \(error)")
            }
        }
    }
    
    private func mergeVideos() {
        guard let mainURL = viewModel.currentProject?.videoURL else { return }
        
        var allURLs = [mainURL]
        allURLs.append(contentsOf: videoItems.map { $0.url })
        
        viewModel.mergeVideos(urls: allURLs)
    }
}

struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
    let duration: Double
}

struct VideoItemCard: View {
    let title: String
    let duration: Double
    let isMain: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isMain ? "film.fill" : "film")
                .font(.system(size: 24))
                .foregroundColor(isMain ? .blue : .gray)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isMain {
                Text("メイン")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d分%02d秒", minutes, seconds)
    }
}

struct ResizeControlView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedPreset: ResizePreset = .original
    @State private var customWidth: String = "1920"
    @State private var customHeight: String = "1080"
    @State private var maintainAspectRatio: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("画面サイズを変更")
                .font(.headline)
                .foregroundColor(.white)
                
                Text("動画の解像度を変更します")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // プリセット選択
                VStack(alignment: .leading, spacing: 12) {
                    Text("プリセット")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ResizePreset.allCases, id: \.self) { preset in
                            ResizePresetButton(
                                preset: preset,
                                isSelected: selectedPreset == preset
                            ) {
                                selectedPreset = preset
                                if preset != .custom {
                                    let size = preset.size
                                    customWidth = String(Int(size.width))
                                    customHeight = String(Int(size.height))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // カスタムサイズ入力
                if selectedPreset == .custom {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("カスタムサイズ")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("幅")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                TextField("1920", text: $customWidth)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Text("×")
                                .foregroundColor(.gray)
                                .padding(.top, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("高さ")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                TextField("1080", text: $customHeight)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        Toggle("縦横比を維持", isOn: $maintainAspectRatio)
                            .foregroundColor(.white)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }
                
                // 現在のサイズ表示
                if let project = viewModel.currentProject, project.videoURL != nil {
                    VStack(spacing: 8) {
                        Text("現在のサイズ")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("\(Int(customWidth) ?? 1920) × \(Int(customHeight) ?? 1080)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
        }
        .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // 適用ボタン
                Button("サイズ変更を適用") {
                    applyResize()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }
    
    private func applyResize() {
        guard let width = Int(customWidth),
              let height = Int(customHeight),
              width > 0,
              height > 0 else {
            return
        }
        
        viewModel.resizeVideo(width: width, height: height, maintainAspectRatio: maintainAspectRatio)
    }
}

enum ResizePreset: String, CaseIterable {
    case original = "オリジナル"
    case uhd4k = "4K UHD"
    case fullHD = "Full HD"
    case hd = "HD"
    case sd = "SD"
    case square = "正方形"
    case vertical = "縦動画"
    case custom = "カスタム"
    
    var size: CGSize {
        switch self {
        case .original:
            return CGSize(width: 1920, height: 1080)
        case .uhd4k:
            return CGSize(width: 3840, height: 2160)
        case .fullHD:
            return CGSize(width: 1920, height: 1080)
        case .hd:
            return CGSize(width: 1280, height: 720)
        case .sd:
            return CGSize(width: 854, height: 480)
        case .square:
            return CGSize(width: 1080, height: 1080)
        case .vertical:
            return CGSize(width: 1080, height: 1920)
        case .custom:
            return CGSize(width: 1920, height: 1080)
        }
    }
    
    var description: String {
        switch self {
        case .original:
            return "元のサイズ"
        case .uhd4k:
            return "3840×2160"
        case .fullHD:
            return "1920×1080"
        case .hd:
            return "1280×720"
        case .sd:
            return "854×480"
        case .square:
            return "1080×1080"
        case .vertical:
            return "1080×1920"
        case .custom:
            return "任意のサイズ"
        }
    }
}

struct ResizePresetButton: View {
    let preset: ResizePreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(preset.rawValue)
                    .font(.body)
                    .fontWeight(isSelected ? .bold : .regular)
                
                Text(preset.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .blue : .white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct SpeedControlView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var speed: Double = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("再生速度: \(String(format: "%.1fx", speed))")
                .font(.headline)
                .foregroundColor(.white)
            
            Slider(value: $speed, in: 0.25...4.0, step: 0.25)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct RotateControlView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedRotation: RotationAngle = .degrees90
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            Text("回転")
                .font(.headline)
                .foregroundColor(.white)
            
                // 回転プレビュー
                rotationPreviewSection
                
                // 回転角度選択
                rotationSelectionSection
                
                // 適用ボタン
                Button(action: {
                    applyRotation()
                }) {
                    HStack {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 18))
                        Text("回転を適用")
                            .font(.body)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.currentProject == nil)
            }
            .padding()
        }
    }
    
    private var rotationPreviewSection: some View {
        VStack(spacing: 12) {
            Text("回転角度プレビュー")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ZStack {
                // プレビュー矩形
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 150)
                    .overlay(
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            Text("動画")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    )
                    .rotationEffect(selectedRotation.angle)
            }
            .frame(height: 250)
            
            Text("\(selectedRotation.rawValue)")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var rotationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("回転角度を選択")
                .font(.subheadline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(RotationAngle.allCases, id: \.self) { rotation in
                    RotationButton(
                        rotation: rotation,
                        isSelected: selectedRotation == rotation
                    ) {
                        selectedRotation = rotation
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private func applyRotation() {
        viewModel.rotateVideo(angle: selectedRotation)
    }
}

// MARK: - Rotation Angle

enum RotationAngle: String, CaseIterable {
    case degrees90 = "90° 時計回り"
    case degrees180 = "180°"
    case degrees270 = "270° (90° 反時計回り)"
    case degrees360 = "360° (0°)"
    
    var angle: Angle {
        switch self {
        case .degrees90:
            return .degrees(90)
        case .degrees180:
            return .degrees(180)
        case .degrees270:
            return .degrees(270)
        case .degrees360:
            return .degrees(0)
        }
    }
    
    var transform: CGAffineTransform {
        switch self {
        case .degrees90:
            return CGAffineTransform(rotationAngle: .pi / 2)
        case .degrees180:
            return CGAffineTransform(rotationAngle: .pi)
        case .degrees270:
            return CGAffineTransform(rotationAngle: .pi * 3 / 2)
        case .degrees360:
            return .identity
        }
    }
    
    var icon: String {
        switch self {
        case .degrees90:
            return "rotate.right"
        case .degrees180:
            return "arrow.triangle.2.circlepath"
        case .degrees270:
            return "rotate.left"
        case .degrees360:
            return "arrow.clockwise"
        }
    }
}

// MARK: - Rotation Button

struct RotationButton: View {
    let rotation: RotationAngle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: rotation.icon)
                    .font(.system(size: 28))
                
                Text(rotation.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .blue : .white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct CropControlView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedPreset: CropPreset = .original
    @State private var customCropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var isDragging: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("クロップ")
                .font(.headline)
                .foregroundColor(.white)
                
                // プレビュー（クロップ範囲を表示）
                cropPreviewSection
                
                // アスペクト比プリセット
                presetSelectionSection
                
                // カスタム調整
                if selectedPreset == .custom {
                    customAdjustmentSection
                }
                
                // 適用ボタン
                Button(action: {
                    applyCrop()
                }) {
                    HStack {
                        Image(systemName: "crop")
                            .font(.system(size: 18))
                        Text("クロップを適用")
                            .font(.body)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.currentProject == nil)
        }
        .padding()
        }
    }
    
    // MARK: - Crop Preview Section
    
    private var cropPreviewSection: some View {
        VStack(spacing: 12) {
            Text("クロップ範囲プレビュー")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            GeometryReader { geometry in
                let previewSize = min(geometry.size.width, 300)
                
                ZStack {
                    // 元の動画フレーム
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: previewSize, height: previewSize * 9/16)
                        .overlay(
                            Text("動画プレビュー")
                                .foregroundColor(.gray)
                        )
                    
                    // クロップ範囲
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 3)
                        .fill(Color.blue.opacity(0.1))
                        .frame(
                            width: previewSize * getCropSize().width,
                            height: previewSize * 9/16 * getCropSize().height
                        )
                        .offset(
                            x: previewSize * getCropOffset().x - previewSize / 2,
                            y: previewSize * 9/16 * getCropOffset().y - previewSize * 9/16 / 2
                        )
                    
                    // クロップ情報
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(getCropInfoText())
                                .font(.caption)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .padding(8)
                        }
                    }
                    .frame(width: previewSize, height: previewSize * 9/16)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Preset Selection Section
    
    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アスペクト比")
                .font(.subheadline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CropPreset.allCases, id: \.self) { preset in
                    CropPresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset
                    ) {
                        selectedPreset = preset
                        updateCropRectForPreset(preset)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Custom Adjustment Section
    
    private var customAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("カスタム調整")
                .font(.subheadline)
                .foregroundColor(.white)
            
            // X位置
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("X位置")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", customCropRect.origin.x * 100))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Slider(value: Binding(
                    get: { customCropRect.origin.x },
                    set: { newValue in
                        customCropRect.origin.x = max(0, min(1 - customCropRect.width, newValue))
                    }
                ), in: 0...1)
            }
            
            // Y位置
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Y位置")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", customCropRect.origin.y * 100))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Slider(value: Binding(
                    get: { customCropRect.origin.y },
                    set: { newValue in
                        customCropRect.origin.y = max(0, min(1 - customCropRect.height, newValue))
                    }
                ), in: 0...1)
            }
            
            // 幅
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("幅")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", customCropRect.width * 100))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Slider(value: Binding(
                    get: { customCropRect.width },
                    set: { newValue in
                        customCropRect.size.width = max(0.1, min(1 - customCropRect.origin.x, newValue))
                    }
                ), in: 0.1...1)
            }
            
            // 高さ
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("高さ")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", customCropRect.height * 100))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Slider(value: Binding(
                    get: { customCropRect.height },
                    set: { newValue in
                        customCropRect.size.height = max(0.1, min(1 - customCropRect.origin.y, newValue))
                    }
                ), in: 0.1...1)
            }
            
            // リセットボタン
            Button("リセット") {
                customCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func getCropSize() -> CGSize {
        switch selectedPreset {
        case .original:
            return CGSize(width: 1, height: 1)
        case .square:
            return CGSize(width: 9.0/16.0, height: 9.0/16.0)
        case .landscape16_9:
            return CGSize(width: 1, height: 1)
        case .portrait9_16:
            return CGSize(width: 9.0/16.0, height: 1)
        case .landscape4_3:
            return CGSize(width: 1, height: 0.75)
        case .portrait3_4:
            return CGSize(width: 0.75, height: 1)
        case .custom:
            return customCropRect.size
        }
    }
    
    private func getCropOffset() -> CGPoint {
        switch selectedPreset {
        case .original:
            return CGPoint(x: 0.5, y: 0.5)
        case .square:
            return CGPoint(x: 0.5, y: 0.5)
        case .landscape16_9:
            return CGPoint(x: 0.5, y: 0.5)
        case .portrait9_16:
            return CGPoint(x: 0.5, y: 0.5)
        case .landscape4_3:
            return CGPoint(x: 0.5, y: 0.5)
        case .portrait3_4:
            return CGPoint(x: 0.5, y: 0.5)
        case .custom:
            return CGPoint(
                x: customCropRect.origin.x + customCropRect.width / 2,
                y: customCropRect.origin.y + customCropRect.height / 2
            )
        }
    }
    
    private func getCropInfoText() -> String {
        let size = getCropSize()
        return String(format: "%.0f%% × %.0f%%", size.width * 100, size.height * 100)
    }
    
    private func updateCropRectForPreset(_ preset: CropPreset) {
        switch preset {
        case .original:
            customCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        case .square:
            let size = 9.0 / 16.0
            customCropRect = CGRect(
                x: (1 - size) / 2,
                y: (1 - size) / 2,
                width: size,
                height: size
            )
        case .landscape16_9:
            customCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        case .portrait9_16:
            let width = 9.0 / 16.0
            customCropRect = CGRect(
                x: (1 - width) / 2,
                y: 0,
                width: width,
                height: 1
            )
        case .landscape4_3:
            let height = 0.75
            customCropRect = CGRect(
                x: 0,
                y: (1 - height) / 2,
                width: 1,
                height: height
            )
        case .portrait3_4:
            let width = 0.75
            customCropRect = CGRect(
                x: (1 - width) / 2,
                y: 0,
                width: width,
                height: 1
            )
        case .custom:
            break
        }
    }
    
    private func applyCrop() {
        let cropRect: CGRect
        
        switch selectedPreset {
        case .original:
            // オリジナルサイズのまま（クロップしない）
            return
        case .custom:
            cropRect = customCropRect
        default:
            cropRect = customCropRect
        }
        
        viewModel.cropVideo(cropRect: cropRect)
    }
}

// MARK: - Crop Preset

enum CropPreset: String, CaseIterable {
    case original = "オリジナル"
    case square = "正方形 (1:1)"
    case landscape16_9 = "横長 (16:9)"
    case portrait9_16 = "縦長 (9:16)"
    case landscape4_3 = "横長 (4:3)"
    case portrait3_4 = "縦長 (3:4)"
    case custom = "カスタム"
    
    var icon: String {
        switch self {
        case .original:
            return "rectangle"
        case .square:
            return "square"
        case .landscape16_9:
            return "rectangle.landscape"
        case .portrait9_16:
            return "rectangle.portrait"
        case .landscape4_3:
            return "rectangle.landscape.split.2x1"
        case .portrait3_4:
            return "rectangle.portrait.split.2x1"
        case .custom:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - Crop Preset Button

struct CropPresetButton: View {
    let preset: CropPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 24))
                
                Text(preset.rawValue)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .blue : .white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

