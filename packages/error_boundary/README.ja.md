# error_boundary

[English](README.md) | **日本語**

React の Error Boundary にインスパイアされた、ウィジェットツリーに宣言的なエラーハンドリングを提供する Flutter パッケージです。

## 概要

`ErrorBoundary` は、ウィジェットのサブツリー内で発生したエラーをキャッチし、画面をクラッシュさせる代わりに fallback を表示します。エラーからの回復は組み込みのリセットで行えるほか、reset keys が変化したときに自動でリセットすることもできます。発生したエラーは `onError` コールバックで受け取り、ログやレポートに回せます。`ZoneWidget` とも統合でき、少ないコードで導入できます。

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

### ErrorBoundary - エラーを優雅に処理

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

### ErrorBoundary

`ErrorBoundary` は子ウィジェットからのエラーをキャッチし、クラッシュする
代わりにフォールバック UI を表示します（React の Error Boundary と同じ
思想）。

**重要 — 自動キャッチが機能するのは、`Element` が `ZoneElement` を mixin した
ウィジェット（`ZoneWidget` / `StatefulZoneWidget` / `hooks_async_zone` の
基底クラスなど）の `build()` 内の throw だけ**。素の `StatelessWidget` /
`StatefulWidget`、あるいは `build()` の外（イベントハンドラ・post-frame
callback・`Timer` callback など）で throw された例外は **自動的にはキャッチ
されません**。これらのケースでは、任意のウィジェットから
`ErrorBoundary.of(context).showBoundary(error)` を呼んでください — 手動
トリガーは `ZoneElement` を必要としません。

**主な機能:**

- 宣言的なエラーハンドリング
- エラーから回復するためのリセット機能
- ログ・副作用用の `onError` / `onReset` コールバック
- 外部値変化で自動リセットする `resetKeys`
- `showBoundary` によるプログラマティックなトリガー

## 高度な使用方法

### `resetKeys` による自動リセット

`resetKeys` を渡すと、外部値が変化したときに自動でバウンダリーをリセットできます。ルート引数やユーザー ID、クエリキーなどが変わって以前のエラーがもう関係なくなった場合に便利です：

```dart
ErrorBoundary(
  resetKeys: [userId],
  builder: (context, error, reset) => ErrorView(
    error: error,
    onRetry: reset,
  ),
  child: UserProfile(userId: userId),
)
```

`resetKeys` 内のいずれかの値が直前のレンダリングと異なる場合（等価性で比較）、エラー状態がクリアされ `onReset` が発火します。

### 入れ子のバウンダリー

`ErrorBoundary` を入れ子にすると、フォールバックから throw されたエラーは外側の `ErrorBoundary` にエスカレートします（React の error boundary の意味論に準じます）。対象は次のとおりです：

- フォールバック `builder` から同期的に throw されたエラー
- フォールバック内の `ZoneWidget` から throw されたエラー

```dart
ErrorBoundary( // outer - inner で扱えないエラーを処理
  builder: (context, error, reset) => Text('Outer: $error'),
  child: ErrorBoundary( // inner
    builder: (context, error, reset) {
      if (error is AuthException) throw error; // outer に委譲
      return RetryView(error: error, onRetry: reset);
    },
    child: HomePage(),
  ),
)
```

外側のバウンダリーが存在しない場合、再 throw は未処理のビルドエラーとして表面化します。

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

| プロパティ  | 型                     | 説明                                         |
| ----------- | ---------------------- | -------------------------------------------- |
| `builder`   | `ErrorFallbackBuilder` | エラー発生時のフォールバック UI のビルダー   |
| `child`     | `Widget`               | ラップする子ウィジェット                     |
| `onError`   | `Function?`            | エラーがキャッチされた時のコールバック       |
| `onReset`   | `Function?`            | バウンダリーがリセットされた時のコールバック |
| `resetKeys` | `List<Object?>?`       | これらの値が変化したとき自動でリセット       |

**メソッド:**

- `ErrorBoundary.of(context)` - 手動制御のための `ErrorBoundaryProvider` を返します

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
