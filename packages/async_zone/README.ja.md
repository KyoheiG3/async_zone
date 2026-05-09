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

class MyDataWidget extends StatefulZoneWidget {
  const MyDataWidget({super.key});

  @override
  State<MyDataWidget> createState() => _MyDataWidgetState();
}

class _MyDataWidgetState extends State<MyDataWidget> {
  // future をフィールドに保持して、リビルド間で同じインスタンスを再利用する
  late final Future<String> _future = _fetchData();

  Future<String> _fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }

  @override
  Widget build(BuildContext context) {
    // use() を使ってキャッシング
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

**⚠️ 重要:** `build()` 内で throw された future とエラーを処理するには、ウィジェットが `ZoneElement` を使用する必要があります。

**要件:**

- `ZoneWidget` または `StatefulZoneWidget` を継承する
- future/エラーは `build()` メソッド内でのみ throw する
- 通常の `StatelessWidget`/`StatefulWidget` では動作しません

**正しい使い方:**

```dart
class MyWidget extends StatefulZoneWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final _future = fetchData();

  @override
  Widget build(BuildContext context) {
    throw _future;  // ✅ build() 内で future を throw
    // または: final data = AsyncZone.of(context).use(_future);
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
    // future をメモ化してリビルド間で同じインスタンスを再利用する
    final future = useMemoized(() => fetchData());

    // ✅ Hooks と AsyncZone の両方が使えます！
    final data = AsyncZone.of(context).use(future);

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

キャッシュキーは **`Future` インスタンスそのものの同一性** です。リビルドのたびに新しい `Future` が生成されるような書き方をすると、キャッシュは一度もヒットせず無限リビルドループに陥ります。代表的な失敗パターン：

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

`Future.then()` は呼ぶたびに **新しい `Future`** を返します。

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

@override
Widget build(BuildContext context) {
  final name = AsyncZone.of(context).use(_nameFuture);
  return Text(name);
}
```

**❌ `build()` の中で async クロージャを即時実行する**

クロージャ呼び出しはそのたびに新しい `Future` を生成します：

```dart
@override
Widget build(BuildContext context) {
  final user = AsyncZone.of(context).use((() async {
    return await fetchUser();
  })());
  return Text(user.name);
}
```

✅ Future を `build()` の外で 1 度だけ作って使い回す：

```dart
late final Future<User> _userFuture = (() async {
  return await fetchUser();
})();

@override
Widget build(BuildContext context) {
  final user = AsyncZone.of(context).use(_userFuture);
  return Text(user.name);
}
```

**判断基準:** `use()` に渡している **その `Future` インスタンス** を保持している `late final` フィールド・`State` フィールド・hook ref（`useMemoized` / `useState`）・外部ストアが指し示せないなら、キャッシュはミスします。迷ったら、まず Future を名前付き変数に入れてから `use()` に渡してください。

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

| プロパティ            | 型       | 説明                                               |
| --------------------- | -------- | -------------------------------------------------- |
| `fallback`            | `Widget` | 非同期処理が保留中の間に表示するウィジェット       |
| `child`               | `Widget` | メインコンテンツウィジェット                       |
| `allowParallelBuilds` | `bool`   | 並列ビルドを許可するかどうか（デフォルト: `true`） |

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
