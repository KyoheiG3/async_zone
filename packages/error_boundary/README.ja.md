# error_boundary

[English](README.md) | **日本語**

React の Error Boundary にインスパイアされた、ウィジェットツリーに宣言的なエラーハンドリングを提供する Flutter パッケージです。

## 機能

- 🛡️ **ErrorBoundary**: ウィジェットツリー内のエラーをキャッチして処理
- 🎯 **ZoneWidget 統合**: ZoneWidget とのシームレスなエラーハンドリング
- 🔄 **リセット機能**: 組み込みのリセット機能でエラーから回復
- 📊 **エラーコールバック**: onError コールバックでエラーをログ記録・レポート
- 🚀 **シンプルな API**: 最小限のボイラープレートで強力な機能

## インストール

```bash
flutter pub add error_boundary
```

または、`pubspec.yaml` に手動で追加：

```yaml
dependencies:
  error_boundary:
```

その後、以下を実行：

```bash
flutter pub get
```

## クイックスタート

### ErrorBoundary - エラーの優雅な処理

ウィジェットツリー内のエラーをキャッチしてフォールバック UI を表示：

```dart
import 'package:error_boundary/error_boundary.dart';

ErrorBoundary(
  builder: (context, error, reset) => Column(
    children: [
      Text('エラー: $error'),
      ElevatedButton(
        onPressed: reset,
        child: Text('再試行'),
      ),
    ],
  ),
  onError: (error, stackTrace) {
    // エラーレポートサービスにログを送信
    print('エラーがキャッチされました: $error');
  },
  child: MyWidget(),
)
```

## コアコンセプト

### ZoneWidget と ZoneElement - 重要な要件

**⚠️ 重要:** `build()` 内で throw されたエラーを処理するには、ウィジェットが `ZoneElement` を使用する必要があります。

**要件:**

- `ZoneWidget` または `StatefulZoneWidget` を継承する
- エラーは `build()` メソッド内でのみ throw する
- 通常の `StatelessWidget`/`StatefulWidget` では動作しません

**正しい使い方:**

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw Exception('Error');  // ✅ build() 内でエラーを throw
  }
}
```

**間違った使い方:**

```dart
class MyWidget extends StatelessWidget {  // ❌ ZoneWidget ではない
  @override
  Widget build(BuildContext context) {
    throw Exception('Error');  // ❌ キャッチされません
  }
}

class MyButton extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => throw Exception('Error'),  // ❌ build() の外
      child: Text('Click'),
    );
  }
}
```

### ErrorBoundary

`ErrorBoundary` は子ウィジェットからのエラーをキャッチし、クラッシュする代わりにフォールバック UI を表示します。React の Error Boundary にインスパイアされています。

**重要:** `ZoneWidget` または `StatefulZoneWidget` の `build()` メソッドから throw されたエラーのみがキャッチされます。

**主な機能:**

- 宣言的なエラーハンドリング
- エラーから回復するためのリセット機能
- ログ記録/レポート用のエラーコールバック
- `showBoundary` によるプログラマティックなエラートリガー

## 高度な使用方法

### 子孫から Error Boundary にアクセス

ツリーのどこからでもエラーバウンダリーを手動でトリガーできます。自動的なエラーキャッチには `ZoneWidget` が必要ですが、手動でのトリガーは**任意のウィジェット**（通常の `StatelessWidget` や `StatefulWidget` を含む）から実行可能です：

```dart
// 任意のウィジェットから実行可能 - ZoneWidget を継承する必要なし
class MyRegularWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final provider = ErrorBoundary.of(context);

        // 手動でエラーを表示
        provider.showBoundary(Exception('何か問題が発生しました'));
      },
      child: Text('エラーをトリガー'),
    );
  }
}

// エラーバウンダリーをリセット
final provider = ErrorBoundary.of(context);
provider.resetBoundary();
```

## API リファレンス

### ErrorBoundary

| プロパティ | 型                     | 説明                                         |
| ---------- | ---------------------- | -------------------------------------------- |
| `builder`  | `ErrorFallbackBuilder` | エラー発生時のフォールバック UI のビルダー   |
| `child`    | `Widget`               | ラップする子ウィジェット                     |
| `onError`  | `Function?`            | エラーがキャッチされた時のコールバック       |
| `onReset`  | `Function?`            | バウンダリーがリセットされた時のコールバック |

**メソッド:**

- `ErrorBoundary.of(context)` - 手動制御のための `ErrorBoundaryProvider` を返す

### ZoneWidget / StatefulZoneWidget

エラーハンドリングが統合された抽象基底クラス。

- `StatelessWidget` には `ZoneWidget` を継承
- `StatefulWidget` には `StatefulZoneWidget` を継承

## ライセンス

このプロジェクトは BSD 3-Clause License の下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## インスピレーション

このパッケージは以下からインスパイアされています：

- エラーハンドリングのための React の Error Boundary
- Flutter の宣言的 UI 原則
