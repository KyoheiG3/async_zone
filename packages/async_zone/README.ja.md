# async_zone

[English](README.md) | **日本語**

React の Suspense と Error Boundary にインスパイアされた、宣言的な非同期処理とエラーバウンダリーを提供する Flutter パッケージです。

## 機能

- 🔄 **AsyncZone**: 自動フォールバック UI を備えた宣言的な非同期処理
- 🛡️ **ErrorZoneWidget**: React ライクなライフサイクルメソッドを持つカスタムエラーハンドリング
- 🎯 **ZoneWidget**: 非同期処理とエラーハンドリングのシームレスな統合
- 🚀 **シンプルな API**: 最小限のボイラープレートで強力な機能
- ⚡ **パフォーマンス**: 効率的なキャッシングとリビルド最適化

## インストール

```bash
flutter pub add async_zone
```

または、`pubspec.yaml` に手動で追加：

```yaml
dependencies:
  async_zone:
```

その後、以下を実行：

```bash
flutter pub get
```

## クイックスタート

### AsyncZone - 非同期処理の扱い（React Suspense にインスパイア）

ウィジェットツリーを `AsyncZone` でラップし、future を throw することで自動的にフォールバック UI を表示します：

```dart
import 'package:async_zone/async_zone.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AsyncZone(
      fallback: CircularProgressIndicator(),
      child: MyDataWidget(),
    );
  }
}

class MyDataWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    // use() を使ってキャッシング
    final data = AsyncZone.of(context).use(fetchData());
    return Text(data);
  }

  Future<String> fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }
}
```

### ErrorZoneWidget - カスタムエラーハンドリング（React Error Boundary にインスパイア）

React ライクなライフサイクルメソッドでカスタムエラーハンドリングを作成：

```dart
import 'package:async_zone/async_zone.dart';

class MyErrorZone extends ErrorZoneWidget<({Object? error})> {
  const MyErrorZone({super.key, required this.child});

  final Widget child;

  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    // エラーレポートサービスにログを送信
    print('エラーがキャッチされました: $error');
  }

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Column(
        children: [
          Text('エラー: ${state.error}'),
          ElevatedButton(
            onPressed: resetErrorBoundary,
            child: Text('再試行'),
          ),
        ],
      );
    }
    return child;
  }
}
```

> **Note:** よりシンプルなエラーバウンダリー実装については、[error_boundary](https://pub.dev/packages/error_boundary) パッケージをご確認ください。

## コアコンセプト

### ZoneWidget と ZoneElement - 重要な要件

**⚠️ 重要:** `build()` 内で throw された future とエラーを処理するには、ウィジェットが `ZoneElement` を使用する必要があります。

**要件:**

- `ZoneWidget` または `StatefulZoneWidget` を継承する
- future/エラーは `build()` メソッド内でのみ throw する
- 通常の `StatelessWidget`/`StatefulWidget` では動作しません

**正しい使い方:**

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw fetchData();  // ✅ build() 内で future を throw
    // または: final data = AsyncZone.of(context).use(fetchData());
  }
}
```

**間違った使い方:**

```dart
class MyWidget extends StatelessWidget {  // ❌ ZoneWidget ではない
  @override
  Widget build(BuildContext context) {
    throw fetchData();  // ❌ キャッチされません
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

#### 他のウィジェットタイプと ZoneElement を使用する

`ZoneWidget` や `StatefulZoneWidget` を継承する必要はありません - `ZoneElement` を mixin した element を作成すれば、**任意のウィジェットタイプ**で使用できます。これにより、`flutter_hooks` などの他のライブラリと組み合わせることができます：

```dart
// HookWidget と ZoneElement を組み合わせたカスタム基底クラス
abstract class ZoneHookWidget extends HookWidget {
  const ZoneHookWidget({super.key});

  @override
  ZoneHookElement createElement() => ZoneHookElement(this);
}

// HookElement と ZoneElement を組み合わせたカスタム element
class ZoneHookElement extends StatelessElement with HookElement, ZoneElement {
  ZoneHookElement(super.widget);
}

// ZoneWidget のように使用できます
class MyWidget extends ZoneHookWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = useState(0);

    // ✅ Hooks と AsyncZone の両方が使えます！
    final data = AsyncZone.of(context).use(fetchData());

    return Column(
      children: [
        Text('カウンター: ${counter.value}'),
        Text('データ: $data'),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: Text('増加'),
        ),
      ],
    );
  }
}
```

**重要なポイント:**

- 本質的な要件は、ウィジェットの element が `ZoneElement` を mixin していること
- `ZoneElement` を `HookElement` や他のカスタム element と組み合わせられます
- これにより async_zone は様々な Flutter ライブラリやパターンと互換性があります

### AsyncZone

`AsyncZone` は非同期処理を管理し、処理中はフォールバック UI を表示します。React の Suspense にインスパイアされています。

#### 推奨 - use() を使ったキャッシング

推奨される方法は、自動的にキャッシングを処理する `use()` を使用することです：

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(fetchData());
    return Text(data);
  }

  Future<String> fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }
}
```

#### 上級 - 直接 throw

future を直接 throw することもできますが、無限リビルドループを避けるために慎重な管理が必要です。future は同じインスタンスを維持するためにフィールドに保存する必要があります：

```dart
class MyWidget extends StatefulZoneWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final Future<String> _future = _fetchData();
  String? _data;

  Future<String> _fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }

  @override
  Widget build(BuildContext context) {
    if (_data != null) {
      return Text(_data!);
    }

    // 全く同じ future インスタンスを保存して再利用する必要があります
    _future.then((data) {
      if (mounted) setState(() => _data = data);
    });
    throw _future;
  }
}
```

**直接 `throw` vs `use()`:**

- **`use()`**（推奨）: 自動キャッシングでより簡単に使用できます
- **直接 `throw`**: より多くの制御が可能ですが、慎重な状態管理が必要です

## 高度な使用方法

### 並列ビルド vs シーケンシャルビルド

非同期処理が保留中の間、子ウィジェットがビルドできるかどうかを制御：

```dart
AsyncZone(
  allowParallelBuilds: false, // デフォルトは true
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)
```

- `true`（デフォルト）: 保留中の処理があっても子ウィジェットのビルドを続行
- `false`: いずれかの処理が保留中の場合、すべての子ビルドをブロック

### カスタムエラーゾーン

#### Method 1: ErrorZoneWidget を継承

`ErrorZoneWidget` を継承してカスタムエラーハンドリングを作成：

```dart
class MyCustomErrorZone extends ErrorZoneWidget<({Object? error})> {
  const MyCustomErrorZone({super.key, required this.child});

  final Widget child;

  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    // カスタムエラーハンドリングロジック
    reportToAnalytics(error, stackTrace);
  }

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return MyCustomErrorUI(error: state.error!);
    }
    return child;
  }
}
```

#### Method 2: ErrorBoundaryMixin と ErrorZoneElement を直接使用

より多くの制御が必要な場合は、`ErrorBoundaryMixin` を mixin して `ErrorZoneElement` を持つカスタム element を作成：

```dart
class MyCustomWidget extends StatelessWidget with ErrorBoundaryMixin<({Object? error})> {
  const MyCustomWidget({super.key, required this.child});

  final Widget child;

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) => (error: error);

  @override
  Widget build(BuildContext context) => state.error != null
      ? MyCustomErrorUI(error: state.error!)
      : child;

  @override
  MyCustomElement createElement() => MyCustomElement(this);
}

class MyCustomElement extends StatelessElement with ErrorZoneElement<({Object? error})> {
  MyCustomElement(super.widget);

  @override
  MyCustomWidget get widget => super.widget as MyCustomWidget;
}
```

これにより element のライフサイクルを完全に制御できます。

## サンプル

完全なサンプルについては [example](example/) ディレクトリを参照してください：

- 基本的な非同期処理
- ErrorZoneWidget を使ったカスタムエラーゾーン
- ネストされた async zones
- エラー回復パターン
- 状態管理との統合

## API リファレンス

### AsyncZone

| プロパティ            | 型       | 説明                                               |
| --------------------- | -------- | -------------------------------------------------- |
| `fallback`            | `Widget` | 非同期処理が保留中の間に表示するウィジェット       |
| `child`               | `Widget` | メインコンテンツウィジェット                       |
| `allowParallelBuilds` | `bool`   | 並列ビルドを許可するかどうか（デフォルト: `true`） |

**メソッド:**

- `AsyncZone.of(context)` - future を消費するための `AsyncZoneScope` を返す

### ErrorZoneWidget / StatefulErrorZoneWidget

カスタムエラーハンドリング機能を持つ抽象基底クラス。

- Stateless なエラーゾーンには `ErrorZoneWidget` を継承
- Stateful なエラーゾーンには `StatefulErrorZoneWidget` を継承
- `getDerivedStateFromError` を実装してエラー状態を導出
- オプションで `componentDidCatch` をオーバーライドしてエラーのログ記録/レポート
- `resetErrorBoundary()` と `showErrorBoundary()` メソッドで手動制御

### ZoneWidget / StatefulZoneWidget

非同期処理とエラーハンドリングが統合された抽象基底クラス。

- `StatelessWidget` には `ZoneWidget` を継承
- `StatefulWidget` には `StatefulZoneWidget` を継承

### ZoneBuilder

ビルダーパターンでゾーン機能を提供する便利なウィジェット。

カスタムウィジェットクラスを作成せずにゾーンを使用したい場合に便利です。`Builder` に似ていますが、ゾーンサポートが追加されています。

**例:**

```dart
AsyncZone(
  fallback: CircularProgressIndicator(),
  child: ZoneBuilder(
    builder: (context) {
      final data = AsyncZone.of(context).use(fetchData());
      return Text('Data: $data');
    },
  ),
)
```

## 他のソリューションとの比較

### vs FutureBuilder

**FutureBuilder:**

```dart
FutureBuilder<String>(
  future: fetchData(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('エラー: ${snapshot.error}');
    }
    return Text(snapshot.data!);
  },
)
```

**async_zone:**

```dart
AsyncZone(
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)

class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(fetchData());
    return Text(data);
  }
}
```

**利点:**

- ボイラープレートが少ない
- 自動キャッシング
- 関心の分離がより明確
- より良い構成可能性

## ライセンス

このプロジェクトは BSD 3-Clause License の下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## インスピレーション

このパッケージは以下からインスパイアされています：

- 非同期処理のための React の Suspense
- エラーハンドリングのための React の Error Boundary
- Flutter の宣言的 UI 原則
