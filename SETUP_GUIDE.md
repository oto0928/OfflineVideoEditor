# Offline Video Editor - セットアップガイド

## ビルドエラーの解決

Info.plistの競合エラーは解決されました。次に、必要な権限設定をXcodeで追加する必要があります。

## 必要な権限設定の追加方法

### 1. Xcodeでプロジェクトを開く
```bash
cd /Users/oto/Documents/xcode/OfflineVideoEditor
open OfflineVideoEditor.xcodeproj
```

### 2. プロジェクト設定を開く
1. 左のナビゲーターで**OfflineVideoEditor**プロジェクトをクリック
2. **TARGETS** から **OfflineVideoEditor** を選択
3. **Info** タブをクリック

### 3. カスタムiOS Target Propertiesに以下を追加

#### Privacy - Camera Usage Description
- **Key**: `Privacy - Camera Usage Description`
- **Type**: `String`
- **Value**: `動画を録画するためにカメラへのアクセスが必要です`

#### Privacy - Microphone Usage Description
- **Key**: `Privacy - Microphone Usage Description`
- **Type**: `String`
- **Value**: `ナレーションを録音するためにマイクへのアクセスが必要です`

#### Privacy - Photo Library Usage Description
- **Key**: `Privacy - Photo Library Usage Description`
- **Type**: `String`
- **Value**: `動画を読み込むためにフォトライブラリへのアクセスが必要です`

#### Privacy - Photo Library Additions Usage Description
- **Key**: `Privacy - Photo Library Additions Usage Description`
- **Type**: `String`
- **Value**: `編集した動画を保存するためにフォトライブラリへのアクセスが必要です`

#### Privacy - Speech Recognition Usage Description
- **Key**: `Privacy - Speech Recognition Usage Description`
- **Type**: `String`
- **Value**: `字幕を自動生成するために音声認識機能へのアクセスが必要です`

### 4. サポートする画面向きの設定

**Info** タブの **Custom iOS Target Properties** セクションで：

#### Supported interface orientations (iPhone)
- ✅ Portrait (bottom home button)
- ✅ Portrait (top home button)
- ⬜ Landscape (left home button)
- ⬜ Landscape (right home button)

※ 縦画面のみに制限する場合

### 5. ビルド設定の確認

1. **Build Settings** タブを開く
2. 検索ボックスに「Generate Info.plist File」と入力
3. **Generate Info.plist File** が **YES** になっていることを確認

## 簡単な設定方法（推奨）

上記の手動設定が面倒な場合、以下のコードを使用して権限を要求できます：

### OfflineVideoEditorApp.swiftに追加
```swift
import SwiftUI
import AVFoundation
import Speech
import Photos

@main
struct OfflineVideoEditorApp: App {
    init() {
        // 権限のリクエスト
        requestPermissions()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func requestPermissions() {
        // カメラとマイクの権限
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        
        // 音声認識の権限
        SFSpeechRecognizer.requestAuthorization { _ in }
        
        // フォトライブラリの権限
        PHPhotoLibrary.requestAuthorization { _ in }
    }
}
```

ただし、**権限の説明文は必ずXcodeのInfo設定で追加する必要があります**。説明文がないとアプリがクラッシュします。

## ビルドと実行

### シミュレータで実行
```
⌘ + R
```

### 実機で実行
1. iPhoneをMacに接続
2. Xcodeの上部バーでデバイスを選択
3. **Signing & Capabilities** タブで開発チームを選択
4. ⌘ + R でビルド＆実行

## トラブルシューティング

### エラー: "Multiple commands produce Info.plist"
→ **解決済み**: 手動で作成したInfo.plistを削除しました

### エラー: "This app has crashed because it attempted to access privacy-sensitive data"
→ Info タブで権限の説明文を追加してください

### エラー: "Signing for OfflineVideoEditor requires a development team"
→ **Signing & Capabilities** タブで Apple ID を追加して開発チームを選択

### ビルドは成功するが機能が動作しない
→ 一部機能（カメラ、マイク、音声認識）は実機でのみ動作します

## 動作確認

1. ✅ アプリが起動する
2. ✅ 動画インポート画面が表示される
3. ✅ タブナビゲーションが機能する
4. ✅ フォトライブラリから動画を選択できる（実機）
5. ✅ 動画プレビューが表示される
6. ✅ 各編集ツールが表示される

## 次のステップ

1. **基本機能のテスト**
   - 動画の読み込み
   - プレビュー再生
   - 基本的な編集操作

2. **実機テスト**
   - 音声認識機能
   - カメラ機能
   - パフォーマンス確認

3. **機能拡張**
   - Whisper統合
   - 追加エフェクト
   - UI/UX改善

## 参考情報

- [Apple - Requesting Authorization for Media Capture](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/requesting_authorization_for_media_capture_on_ios)
- [Apple - Speech Framework](https://developer.apple.com/documentation/speech)
- [Apple - Photos Framework](https://developer.apple.com/documentation/photokit)

