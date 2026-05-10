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

ウィジェットツリーを `AsyncZone` でラップし、配下の `ZoneWidget` の中で
`use()` を呼ぶだけです。future が pending の間、ゾーンは `child` の代わりに
`fallback` を描画します。

#### `ZoneBuilder` でインライン記述（クラス定義不要）

1 回限りの利用なら、future を安定した場所に保持して `ZoneBuilder` の中で
消費するのが最も手軽です：

```dart
import 'package:async_zone/async_zone.dart';

final greeting = Future.delayed(const Duration(seconds: 2), () => 'Hello!');

AsyncZone(
  fallback: const CircularProgressIndicator(),
  child: ZoneBuilder(
    builder: (context) {
      final text = AsyncZone.of(context).use(greeting);
      return Text(text);
    },
  ),
)
```

#### 再利用可能なウィジェットには `StatefulZoneWidget`

future を自身で保持する再利用可能なウィジェットを作るときは
`StatefulZoneWidget` を継承し、`late final` フィールドに格納してリビルド間で
同じ `Future` インスタンスを使い回します：

```dart
class MyDataWidget extends StatefulZoneWidget {
  const MyDataWidget({super.key});

  @override
  State<MyDataWidget> createState() => _MyDataWidgetState();
}

class _MyDataWidgetState extends State<MyDataWidget> {
  late final Future<String> _future = _fetchData();

  Future<String> _fetchData() async {
    await Future.delayed(const Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }

  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(_future);
    return Text(data);
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

**⚠️ 重要:** suspend / エラー捕捉が機能するのは、`Element` が
`ZoneElement` を mixin したウィジェットの `build()` 内のみです。公開されている
基底クラス（`ZoneWidget` / `StatefulZoneWidget` / `ZoneBuilder`）を使えば
自動的にこの条件を満たします。引っかかりやすい2つの罠：

```dart
// ❌ 素の StatelessWidget — Element が ZoneElement を mixin していないので、
//    throw された Future はそのままビルドエラーとして漏れ出します。
class Wrong extends StatelessWidget {
  @override
  Widget build(BuildContext context) => throw fetchData();
}

// ❌ build() の外（イベントハンドラ等）での throw は捕捉されません。
//    ゾーンが観測するのは build フェーズの throw だけです。
class WrongHandler extends ZoneWidget {
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: () => throw Exception('not caught'),
        child: const Text('Click'),
      );
}
```

`flutter_hooks` の `HookElement` のように他の `Element` mixin と組み合わせたい
場合は、自前でボイラープレートを書くより
[hooks_async_zone](https://pub.dev/packages/hooks_async_zone) を使うのが手軽
です。それ以外のライブラリと組み合わせる場合は、`ZoneElement` を mixin した
カスタム `Element` を定義するだけで動きます。

### AsyncZone

`AsyncZone` は非同期処理を管理し、処理中はフォールバック UI を表示します。React の Suspense にインスパイアされています。

#### 推奨 - use() を使ったキャッシング

`use()` は **Future インスタンスの同一性** をキーにキャッシュします。最初の呼び出しで future をスケジュールして throw し、以降のリビルドで同じインスタンスを渡すとキャッシュされた値を返します。そのため future はどこかで安定して保持する必要があります（`late final` フィールド、親ウィジェットの state、`useMemoized` など）。`build()` の中で直接 `fetchData()` を呼ぶとリビルドのたびに新しい `Future` が生成され、キャッシュは一度もヒットせず、無限リビルドループに陥ります。

```dart
class MyWidget extends StatefulZoneWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final Future<String> _future = _fetchData();

  Future<String> _fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }

  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(_future);
    return Text(data);
  }
}
```

#### よくある落とし穴

キャッシュキーは **`Future` インスタンスそのものの同一性** です。リビルドの
たびに新しい `Future` が生成されるような書き方をすると、キャッシュは一度も
ヒットせず無限リビルドループに陥ります。

**❌ `build()` の中で fetcher を直接呼ぶ**

```dart
@override
Widget build(BuildContext context) {
  // リビルドごとに新しい Future → キャッシュに乗らない
  final data = AsyncZone.of(context).use(fetchData());
  return Text(data);
}
```

**❌ `build()` の中で `.then()` / `.catchError()` / `.timeout()` などをチェーンする**

`Future.then()` は呼ぶたびに **新しい `Future`** を返すので、`build()` 内で
チェーンするのは fetcher を直接呼ぶのと同じ問題になります：

```dart
late final Future<User> _userFuture = fetchUser();

@override
Widget build(BuildContext context) {
  // _userFuture.then(...) はリビルドごとに別の Future
  final name = AsyncZone.of(context).use(_userFuture.then((u) => u.name));
  return Text(name);
}
```

✅ チェーンした Future 自体をフィールドに保持する：

```dart
late final Future<User> _userFuture = fetchUser();
late final Future<String> _nameFuture = _userFuture.then((u) => u.name);
```

**判断基準:** `use()` に渡している **その `Future` インスタンス** を保持して
いる `late final` フィールド・`State` フィールド・hook ref（`useMemoized` /
`useState`）・外部ストアが指し示せないなら、キャッシュはミスします。
`(() async { ... })()` のような即時実行クロージャや、`build()` 内で新しい
`Future` を生成するあらゆる式が同じ罠です。迷ったら、まず Future を名前付き
変数に入れてから `use()` に渡してください。

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

- **`use()`**（推奨）: Future インスタンスの同一性ベースのキャッシュ。同じインスタンスをリビルド間で渡すかぎり簡単に使えます
- **直接 `throw`**: より多くの制御が可能ですが、慎重な状態管理が必要です

## 高度な使用方法

### `AsyncZone` のネスト

`AsyncZone` はそのまま入れ子にできます。各ゾーンが見るのは
`AsyncZone.of(context)` で **そのゾーン自身** に解決されるツリー、つまり
内側ゾーンの `InheritedWidget` より下の `ZoneWidget` だけです。外側のゾーンは
2つのゾーンの間にある（あるいは内側ゾーンの外にある）ウィジェットが suspend
したときにだけ fallback を表示します。

```dart
AsyncZone(                          // outer
  fallback: const Text('outer…'),
  child: Column(children: [
    SuspendsAgainstOuter(),          // ここで suspend → outer fallback
    AsyncZone(                       // inner
      fallback: const Text('inner…'),
      child: SuspendsAgainstInner(), // ここで suspend → inner fallback のみ
    ),
  ]),
)
```

キャッシュ（`use()` の結果）と pending 中のタスク集合は `AsyncZone` ごとに
独立しているので、2つのゾーンが状態を共有することはありません。内側ツリーを
**外側のゾーンに対して** suspend させたい場合は、suspend する側を内側
`AsyncZone` の上に持ち上げてください。

### ライフサイクルと unmount 時の挙動

実アプリで動かしたときに気になりそうな点：

- **unmount で pending な Future はキャンセルされません。** Dart の `Future`
  にキャンセルの仕組みは無いためです。element の `mounted` ガードによって
  後から完了しても黙って無視され、dispose 済みの element に対して
  `markNeedsBuild()` が呼ばれることはありませんが、HTTP リクエストなどの裏の
  処理は走り続けます。本当にキャンセルしたい場合は `package:async` の
  `CancelableOperation` を使ってください。
- **キャッシュはライフサイクルではなく GC で管理されます。**
  `AsyncZoneProviderElement` は完了値を `Expando` で `Future` インスタンス
  ベースに保持するので、Future への参照がなくなれば自動的に GC 対象に
  なります。手動で破棄する API はありません。
- **Hot reload では `late final` フィールドが再評価されません。** 前回の実行
  時に初期化された `late final _future = fetchData()` は hot reload では再
  実行されないため、fetcher の中身を変えたときは hot restart しないと反映
  されません。

### 並行ビルド vs シーケンシャルビルド

このゾーン配下の兄弟 `ZoneWidget` が、他の future の保留中に並行してビルド
できるかどうかを制御します：

```dart
AsyncZone(
  allowConcurrentBuilds: false, // デフォルトは true
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)
```

- `true`（デフォルト）: 各 `ZoneWidget` が独立して評価され、それぞれ自分の
  future で suspend できます。throw された future はすべて並行に await され、
  すべて解決するまで fallback が表示されます。
- `false`: 同時に suspend できる `ZoneWidget` は 1 つだけです。最初の future
  が throw された時点で、そのビルドパスの間は他の `ZoneWidget` は空の
  プレースホルダになり、進行中の future が完了するまで自分の future は
  発火しません（シーケンシャルロード）。`ZoneElement` を mixin していない
  通常の `StatelessWidget` / `StatefulWidget` には影響しません。

### Freeze: リロード中も前の UI を保つ（オプション）

`use()` にはオプションの `freeze` フラグがあります。`true` を渡すと、新しい future が pending の間、`AsyncZone` は **fallback に切り替えるかわりに直前の subtree を画面に残し続けます**。素早く再読み込みする UX で fallback がチラつくのを避けるための「transition 風」の挙動です。

> **Note:** この機能は Suspense 流のプリミティブとして用意してあるだけで、**通常のプロダクト用途には推奨しません**。実アプリでは [Riverpod](https://pub.dev/packages/riverpod) や [fquery](https://pub.dev/packages/fquery) のようなキャッシュライブラリの方が柔軟（stale-while-revalidate、明示的な `isFetching` フラグなど）です。Suspense の枠内に意図的に留まりたい場合のみ使ってください。

#### 基本的な使い方

```dart
final data = AsyncZone.of(context).use(future, freeze: true);
```

#### 初回マウント時の注意

**初回レンダリング** で `freeze: true` を渡すと、保持すべき前 subtree がまだ存在しないので、suspend 中の widget は `Empty()` を返すだけで fallback も表示されません。基本的には **初回 false、以降 true** に切り替える運用になります。

それでもこの機能を使いたい場合、以下のようなヘルパーフックでパターンを切り出せます：

```dart
import 'package:flutter_hooks/flutter_hooks.dart';

T Function<T>(Future<T>) useFreezing() {
  final built = useRef(false);
  final zone = AsyncZone.of(useContext());
  return <T>(future) {
    final value = zone.use(future, freeze: built.value);
    built.value = true;
    return value;
  };
}

// HookZoneWidget / HookErrorZoneWidget の中で:
final use = useFreezing();
final user = use(userFuture);
final post = use(postFuture); // 任意の T で使える
```

`built` は `false` で始まるので、最初の `use()` は通常の fallback 経路を通ります。その呼び出しが正常に値を返した時点で `built` が `true` になり、以降は前 UI を保持しながら新しい future の解決を待つ動作になります。

#### 注意点

- **`isPending` 相当の表示はできません。** freeze 状態が確定するのは Future が throw された **後** で、それを読みたい上流 widget はすでに古い値で build を済ませてしまっています。フェードや opacity を変えるような UX は別途自前の state（`ChangeNotifier` など）で駆動する必要があります。
- **freeze 中は AsyncZone 配下への top-down 伝播が止まります。** 前 subtree を画面に残す代償として、新しい widget config が降りてこない設計です。subtree 内の `Listenable` 由来の再 build は引き続き動きますが、suspend している widget 自身は future が解決するまで表示を更新できません。

### カスタムエラーゾーン

#### `ErrorBoundary` と `ErrorZoneWidget` の使い分け

姉妹パッケージの [error_boundary](https://pub.dev/packages/error_boundary)
は `ErrorZoneWidget` を 1 つの設定可能なウィジェット（`ErrorBoundary`）に
ラップしたものです。低レベル API を直接触る必要がなければ、こちらを使うのが
基本です。

| やりたいこと                                                            | 使うべきもの                             |
| ----------------------------------------------------------------------- | ---------------------------------------- |
| `builder(context, error, reset)` で fallback を組み立てたい             | `ErrorBoundary`（error_boundary）        |
| 外部値の変化で自動リセットしたい（`resetKeys`）                         | `ErrorBoundary`（error_boundary）        |
| サブクラス化せず `onError` / `onReset` コールバックを使いたい           | `ErrorBoundary`（error_boundary）        |
| `(error: …)` 以外の独自 state（リトライ回数・エラー種別など）を持ちたい | `ErrorZoneWidget<T>`                     |
| `StatelessWidget` 以外の階層にエラー境界ライフサイクルを組み込みたい    | `ErrorBoundaryMixin<T>` + 自前 `Element` |

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

### 入れ子のエラーゾーン

`ErrorZoneWidget`（または `ErrorZoneElement` を使った任意のウィジェット）を入れ子にした場合、内側のフォールバック内で throw されたエラーは外側のエラーゾーンにエスカレートします（React の error boundary の意味論と同じ）。対象は：

- 内側のゾーンがフォールバックをレンダリング中に同期的に throw されたエラー
- そのフォールバック配下の `ZoneWidget` から throw されたエラー

```dart
MyOuterErrorZone( // inner で扱えないエラーを処理
  child: MyInnerErrorZone(
    // build / fallback が回復不能なエラーを throw した場合、
    // 外側のゾーンが拾う
    child: SomeWidget(),
  ),
)
```

これは `ErrorZoneElement` mixin レベルで動作するので、`ErrorZoneElement` を使うウィジェットは自動的にこの挙動の対象になります。外側のエラーゾーンが存在しない場合、再 throw は未処理のビルドエラーとして表面化します。

## サンプル

完全なサンプルについては [example](example/) ディレクトリを参照してください：

- 基本的な非同期処理
- ErrorZoneWidget を使ったカスタムエラーゾーン
- ネストされた async zones
- エラー回復パターン
- 状態管理との統合

## API リファレンス

### AsyncZone

| プロパティ              | 型       | 説明                                                              |
| ----------------------- | -------- | ----------------------------------------------------------------- |
| `fallback`              | `Widget` | 非同期処理が保留中の間に表示するウィジェット                      |
| `child`                 | `Widget` | メインコンテンツウィジェット                                      |
| `allowConcurrentBuilds` | `bool`   | 兄弟 `ZoneWidget` が並行に suspend できるか（デフォルト: `true`） |

**メソッド:**

- `AsyncZone.of(context)` - `use()` 経由で future を消費するための `AsyncZoneScope` を返します。`use()` はオプションの `freeze: true` フラグを受け付けます — [Freeze](#freeze-リロード中も前の-ui-を保つオプション) を参照。

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
final future = fetchData(); // リビルド間で同じインスタンスを保持する

AsyncZone(
  fallback: CircularProgressIndicator(),
  child: ZoneBuilder(
    builder: (context) {
      final data = AsyncZone.of(context).use(future);
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

class MyWidget extends StatefulZoneWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final _future = fetchData();

  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(_future);
    return Text(data);
  }
}
```

**利点:**

- フォールバック UI を親に集約でき、各 leaf に重複させずに済む
- `use()` による Future インスタンス同一性ベースのキャッシュ — 同じインスタンスについて future は1回だけ実行される
- 関心の分離がより明確
- より良い構成可能性

## ライセンス

このプロジェクトは BSD 3-Clause License の下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## インスピレーション

このパッケージは以下からインスパイアされています：

- 非同期処理のための React の Suspense
- エラーハンドリングのための React の Error Boundary
- Flutter の宣言的 UI 原則
