//
//  SubtitleToolsView.swift
//  OfflineVideoEditor
//
//  Created by 竹内音碧 on 2025/10/23.
//

import SwiftUI

/// 字幕編集ツールのビュー
struct SubtitleToolsView: View {
    
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var selectedLanguage: String = "ja-JP"
    @State private var showSubtitleEditor = false
    @State private var showSettingsSheet = false
    @State private var showTimelineEditor = false
    @State private var globalSubtitleStyle = SubtitleStyle()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("字幕ツール")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                
                // 言語選択
                languageSelector
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                
                // 字幕自動生成ボタン
                Button(action: {
                    viewModel.generateSubtitles(language: selectedLanguage)
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18))
                        Text("字幕を自動生成")
                            .font(.body)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                
                // 字幕編集メニュー
                if let project = viewModel.currentProject,
                   !project.subtitles.isEmpty {
                    
                    VStack(spacing: 12) {
                        // タイムライン編集
                        Button(action: {
                            showTimelineEditor = true
                        }) {
                            HStack {
                                Image(systemName: "timeline.selection")
                                    .font(.system(size: 18))
                                Text("タイムライン編集")
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.white)
                        
                        // テキスト編集
                        Button(action: {
                            showSubtitleEditor = true
                        }) {
                            HStack {
                                Image(systemName: "text.cursor")
                                    .font(.system(size: 18))
                                Text("テキスト編集")
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.white)
                        
                        // スタイル設定
                        Button(action: {
                            showSettingsSheet = true
                        }) {
                            HStack {
                                Image(systemName: "paintbrush")
                                    .font(.system(size: 18))
                                Text("スタイル設定")
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.white)
                        
                        // 字幕を動画に焼き込む
                        Button(action: {
                            viewModel.burnSubtitlesToVideo()
                        }) {
                            HStack {
                                Image(systemName: "video.badge.checkmark")
                                    .font(.system(size: 18))
                                Text("字幕を動画に焼き込む")
                                    .font(.body)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSubtitleEditor) {
            if viewModel.currentProject != nil {
                SubtitleListEditorView(subtitles: Binding(
                    get: { viewModel.currentProject?.subtitles ?? [] },
                    set: { viewModel.currentProject?.subtitles = $0 }
                ))
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            if viewModel.currentProject != nil {
                SubtitleStyleSettingsView(
                    subtitles: Binding(
                        get: { viewModel.currentProject?.subtitles ?? [] },
                        set: { viewModel.currentProject?.subtitles = $0 }
                    ),
                    globalStyle: $globalSubtitleStyle
                )
            }
        }
        .sheet(isPresented: $showTimelineEditor) {
            if viewModel.currentProject != nil {
                SubtitleTimelineEditorView(
                    subtitles: Binding(
                        get: { viewModel.currentProject?.subtitles ?? [] },
                        set: { viewModel.currentProject?.subtitles = $0 }
                    ),
                    videoDuration: viewModel.currentProject?.duration ?? 0
                )
            }
        }
    }
    
    private var languageSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("言語:")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("言語", selection: $selectedLanguage) {
                    Text("日本語").tag("ja-JP")
                    Text("English").tag("en-US")
                    Text("中文").tag("zh-CN")
                    Text("한국어").tag("ko-KR")
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - テキスト編集画面

/// 字幕リスト編集画面
struct SubtitleListEditorView: View {
    
    @Binding var subtitles: [Subtitle]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubtitle: Subtitle?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(subtitles) { subtitle in
                    SubtitleRow(subtitle: subtitle)
                        .onTapGesture {
                            selectedSubtitle = subtitle
                        }
                }
                .onDelete { indexSet in
                    subtitles.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("テキスト編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完了") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(item: $selectedSubtitle) { subtitle in
                if let index = subtitles.firstIndex(where: { $0.id == subtitle.id }) {
                    SubtitleDetailEditor(subtitle: $subtitles[index])
                }
            }
        }
    }
}

/// 字幕行
struct SubtitleRow: View {
    let subtitle: Subtitle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subtitle.text)
                .font(.body)
            
            HStack {
                Text(formatTime(subtitle.startTime))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("→")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatTime(subtitle.endTime))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

/// 字幕詳細編集
struct SubtitleDetailEditor: View {
    
    @Binding var subtitle: Subtitle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("テキスト") {
                    TextEditor(text: $subtitle.text)
                        .frame(height: 100)
                }
                
                Section("タイミング") {
                    HStack {
                        Text("開始時間")
                        Spacer()
                        Text(formatTime(subtitle.startTime))
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("終了時間")
                        Spacer()
                        Text(formatTime(subtitle.endTime))
                            .foregroundColor(.gray)
                    }
                }
                
                Section("スタイル") {
                    HStack {
                        Text("フォントサイズ")
                        Spacer()
                        Text("\(Int(subtitle.style.fontSize))")
                            .foregroundColor(.gray)
                    }
                    
                    Picker("配置", selection: $subtitle.style.alignment) {
                        Text("左").tag(SubtitleTextAlignment.leading)
                        Text("中央").tag(SubtitleTextAlignment.center)
                        Text("右").tag(SubtitleTextAlignment.trailing)
                    }
                }
            }
            .navigationTitle("字幕編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - タイムライン編集画面

/// 字幕タイムライン編集画面
struct SubtitleTimelineEditorView: View {
    
    @Binding var subtitles: [Subtitle]
    let videoDuration: TimeInterval
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubtitleIndex: Int?
    @State private var isDragging: Bool = false
    @State private var showTimingSettings: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 一括タイミング調整セクション
                if showTimingSettings {
                    TimingAdjustmentSection(subtitles: $subtitles, videoDuration: videoDuration)
                        .transition(.move(edge: .top))
                }
                
                // タイムラインスクロールビュー
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(subtitles.indices, id: \.self) { index in
                            SubtitleTimelineRow(
                                subtitle: $subtitles[index],
                                videoDuration: videoDuration,
                                isSelected: selectedSubtitleIndex == index,
                                onSelect: {
                                    selectedSubtitleIndex = index
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // 選択された字幕の詳細編集
                if let selectedIndex = selectedSubtitleIndex,
                   selectedIndex < subtitles.count {
                    Divider()
                    
                    SubtitleTimeDetailEditor(
                        subtitle: $subtitles[selectedIndex],
                        videoDuration: videoDuration
                    )
                    .frame(height: 200)
                    .background(Color.black)
                }
            }
            .navigationTitle("タイムライン編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完了") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            showTimingSettings.toggle()
                        }
                    }) {
                        Image(systemName: showTimingSettings ? "gearshape.fill" : "gearshape")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Timing Adjustment Section

struct TimingAdjustmentSection: View {
    @Binding var subtitles: [Subtitle]
    let videoDuration: TimeInterval
    @State private var startTimeOffset: Double = 0.0
    @State private var endTimeOffset: Double = 0.0
    @State private var allOffset: Double = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("タイミング調整")
                .font(.headline)
                .foregroundColor(.white)
            
            // 全体の時間をずらす
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("全体の時間調整")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%+.2f秒", allOffset))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Slider(value: $allOffset, in: -5.0...5.0, step: 0.1)
                
                Button("全体を調整") {
                    applyAllOffset()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            // 開始時間を前後に調整
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("開始時間の調整")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%+.2f秒", startTimeOffset))
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("早める")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("遅らせる")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Slider(value: $startTimeOffset, in: -2.0...2.0, step: 0.1)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            // 終了時間を前後に調整
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("終了時間の調整")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%+.2f秒", endTimeOffset))
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("早める")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("遅らせる")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Slider(value: $endTimeOffset, in: -2.0...2.0, step: 0.1)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            // 適用ボタン
            HStack(spacing: 12) {
                Button("リセット") {
                    startTimeOffset = 0.0
                    endTimeOffset = 0.0
                    allOffset = 0.0
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("適用") {
                    applyTimingAdjustment()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    private func applyAllOffset() {
        for index in subtitles.indices {
            let newStart = max(0, subtitles[index].startTime + allOffset)
            let newEnd = min(videoDuration, subtitles[index].endTime + allOffset)
            
            if newStart < newEnd {
                subtitles[index].startTime = newStart
                subtitles[index].endTime = newEnd
            }
        }
        allOffset = 0.0
    }
    
    private func applyTimingAdjustment() {
        for index in subtitles.indices {
            let newStart = max(0, subtitles[index].startTime + startTimeOffset)
            let newEnd = min(videoDuration, subtitles[index].endTime + endTimeOffset)
            
            // 開始時間が終了時間より後にならないように
            if newStart < newEnd {
                subtitles[index].startTime = newStart
                subtitles[index].endTime = newEnd
            }
        }
        
        // リセット
        startTimeOffset = 0.0
        endTimeOffset = 0.0
    }
}

/// タイムライン行
struct SubtitleTimelineRow: View {
    @Binding var subtitle: Subtitle
    let videoDuration: TimeInterval
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // テキストプレビュー
            Text(subtitle.text)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(2)
            
            // タイムラインバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 40)
                    
                    // 字幕の表示範囲
                    let startPos = (subtitle.startTime / videoDuration) * geometry.size.width
                    let endPos = (subtitle.endTime / videoDuration) * geometry.size.width
                    let width = max(20, endPos - startPos)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.blue : Color.green.opacity(0.7))
                        .frame(width: width, height: 40)
                        .offset(x: startPos)
                    
                    // 時間表示
                    HStack {
                        Text(formatTime(subtitle.startTime))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .offset(x: startPos + 4)
                        
                        Spacer()
                        
                        Text(formatTime(subtitle.endTime))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .offset(x: endPos - 40)
                    }
                }
            }
            .frame(height: 40)
            .onTapGesture {
                onSelect()
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 字幕時間詳細編集
struct SubtitleTimeDetailEditor: View {
    @Binding var subtitle: Subtitle
    let videoDuration: TimeInterval
    
    var body: some View {
        VStack(spacing: 16) {
            Text("時間調整")
                .font(.headline)
                .foregroundColor(.white)
            
            // 開始時間
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("開始: \(formatTime(subtitle.startTime))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
                
                Slider(
                    value: Binding(
                        get: { subtitle.startTime },
                        set: { newValue in
                            subtitle.startTime = min(newValue, subtitle.endTime - 0.1)
                        }
                    ),
                    in: 0...videoDuration,
                    step: 0.1
                )
                .accentColor(.green)
            }
            
            // 終了時間
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("終了: \(formatTime(subtitle.endTime))")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                }
                
                Slider(
                    value: Binding(
                        get: { subtitle.endTime },
                        set: { newValue in
                            subtitle.endTime = max(newValue, subtitle.startTime + 0.1)
                        }
                    ),
                    in: 0...videoDuration,
                    step: 0.1
                )
                .accentColor(.red)
            }
            
            // 継続時間表示
            Text("継続時間: \(formatDuration(subtitle.endTime - subtitle.startTime))")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        return String(format: "%.1f秒", duration)
    }
}

// MARK: - スタイル設定画面

/// 字幕スタイル設定画面
struct SubtitleStyleSettingsView: View {
    
    @Binding var subtitles: [Subtitle]
    @Binding var globalStyle: SubtitleStyle
    @Environment(\.dismiss) private var dismiss
    @State private var applyToAll: Bool = true
    @State private var selectedFontName: String = "System"
    @State private var fontSize: Double = 24
    @State private var selectedColor: ColorOption = .white
    @State private var selectedBackgroundColor: ColorOption = .blackTransparent
    @State private var maxWordsPerSubtitle: Int = 15
    
    var body: some View {
        NavigationView {
            Form {
                // 適用対象
                Section {
                    Toggle("全ての字幕に適用", isOn: $applyToAll)
                }
                
                // フォント設定
                Section("フォント") {
                    Picker("フォント", selection: $selectedFontName) {
                        Text("システム").tag("System")
                        Text("ゴシック").tag("HiraKakuProN-W6")
                        Text("明朝").tag("HiraMinProN-W6")
                        Text("丸ゴシック").tag("HiraginoSans-W6")
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("サイズ: \(Int(fontSize))")
                            Spacer()
                        }
                        Slider(value: $fontSize, in: 12...72, step: 1)
                    }
                }
                
                // 色設定
                Section("文字色") {
                    ForEach(ColorOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedColor = option
                        }) {
                            HStack {
                                Circle()
                                    .fill(option.codableColor.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                                
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedColor == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 背景色設定
                Section("背景色") {
                    ForEach(ColorOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedBackgroundColor = option
                        }) {
                            HStack {
                                Circle()
                                    .fill(option.codableColor.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                                
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedBackgroundColor == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 表示量設定
                Section("表示設定") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("一度に表示する文字数: \(maxWordsPerSubtitle)")
                            Spacer()
                        }
                        Slider(value: Binding(
                            get: { Double(maxWordsPerSubtitle) },
                            set: { maxWordsPerSubtitle = Int($0) }
                        ), in: 5...50, step: 1)
                    }
                }
                
                // 適用ボタン
                Section {
                    Button("スタイルを適用") {
                        applyStyle()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("スタイル設定")
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
    
    private func applyStyle() {
        let newStyle = SubtitleStyle(
            fontName: selectedFontName,
            fontSize: fontSize,
            fontColor: selectedColor.codableColor,
            backgroundColor: selectedBackgroundColor.codableColor,
            opacity: 1.0,
            alignment: .center,
            strokeColor: nil,
            strokeWidth: 0
        )
        
        globalStyle = newStyle
        
        if applyToAll {
            for index in subtitles.indices {
                subtitles[index].style = newStyle
            }
        }
    }
}

/// 色選択オプション
enum ColorOption: String, CaseIterable {
    case white = "白"
    case black = "黒"
    case red = "赤"
    case blue = "青"
    case yellow = "黄"
    case green = "緑"
    case blackTransparent = "黒(半透明)"
    case clear = "透明"
    
    var codableColor: CodableColor {
        switch self {
        case .white:
            return CodableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .black:
            return CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        case .red:
            return CodableColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        case .blue:
            return CodableColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        case .yellow:
            return CodableColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .green:
            return CodableColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .blackTransparent:
            return CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        case .clear:
            return CodableColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        }
    }
}

