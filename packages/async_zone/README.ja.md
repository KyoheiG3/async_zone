# async_zone

[English](README.md) | **日本語**

React の Suspense と Error Boundary にインスパイアされた、宣言的な非同期処理とエラーバウンダリーを提供する Flutter パッケージです。

## 機能

- 🔄 **AsyncZone**: 自動フォールバック UI を備えた宣言的な非同期処理
- 🛡️ **ErrorZoneWidget**: React ライクなライフサイクルメソッドを持つカスタムエラーハンドリング
- 🎯 **ZoneWidget**: 非同期処理とエラーハンドリングのシームレスな統合
- 🔀 **TransitionZoneWidget**: 新しい subtree が suspend している間も前回の UI を残す `useTransition` ライクな状態更新
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

#### Stateless: `ZoneWidget` を継承

`ZoneWidget` は `StatelessWidget` に対応するクラスです。future はどこか安定した場所に
保持し（ここでは property として注入）、リビルド間で同じインスタンスを
渡してください：

```dart
import 'package:async_zone/async_zone.dart';

class Greeting extends ZoneWidget {
  const Greeting({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final text = AsyncZone.of(context).use(future);
    return Text(text);
  }
}

// 利用例
final greeting = Future.delayed(const Duration(seconds: 2), () => 'Hello!');

AsyncZone(
  fallback: const CircularProgressIndicator(),
  child: Greeting(future: greeting),
)
```

#### Stateful: `StatefulZoneWidget` を継承

`StatefulZoneWidget` は `StatefulWidget` に対応するクラスです。ウィジェット自身が
future を保持する場合は、`late final` フィールドに格納してリビルド間で
同じ `Future` インスタンスを再利用します：

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

#### インライン版: `ZoneBuilder`

クラス定義が冗長になる 1 回限りのケースでは、`ZoneBuilder` でインラインに
消費できます。同じルールが適用されます — future は安定した場所に保持し、
builder の中で生成しないでください：

```dart
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

> **Note:** よりシンプルなエラーバウンダリー実装については、[error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary) パッケージをご確認ください。

## コアコンセプト

### ZoneWidget と ZoneElement - 重要な要件

**⚠️ 重要:** suspend / エラー捕捉が機能するのは、`Element` が
`ZoneElement` を mixin したウィジェットの `build()` 内のみです。公開されている
基底クラス（`ZoneWidget` / `StatefulZoneWidget` / `ZoneBuilder`）を使えば
自動的にこの条件を満たします。引っかかりやすい 2 つの罠：

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
[hooks_async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/hooks_async_zone) を使うのが手軽
です。それ以外のライブラリと組み合わせる場合は、`ZoneElement` を mixin した
カスタム `Element` を定義するだけで動作します。

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
`useState`）・外部ストアを特定できない場合は、キャッシュはミスします。
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
- **直接 `throw`**: より細かい制御が可能ですが、慎重な状態管理が必要です

## 高度な使用方法

### `AsyncZone` のネスト

`AsyncZone` はそのまま入れ子にできます。各ゾーンが見るのは
`AsyncZone.of(context)` で **そのゾーン自身** に解決されるツリー、つまり
内側ゾーンの `InheritedWidget` より下の `ZoneWidget` だけです。外側のゾーンは
2 つのゾーンの間にある（あるいは内側ゾーンの外側にある）ウィジェットが suspend
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
独立しているので、2 つのゾーンが状態を共有することはありません。内側ツリーを
**外側のゾーンに対して** suspend させたい場合は、suspend する側を内側
`AsyncZone` の上に持ち上げてください。

### Transition（useTransition ライク）

`TransitionZoneWidget` を使うと、状態更新で suspend が発生しても囲みの `AsyncZone` の fallback がちらつきません。React の `useTransition` 相当です。transition 進行中は直前の subtree が画面に残ったまま、`isPending` が suspend した Future を最初に追跡するフレームと同じフレームで `true` になります。

`TransitionZoneWidget` は `AsyncZone` の上に配置し、suspend する部分だけを `AsyncZone` で囲みます。トリガー（ボタン）は transition scope の中・`AsyncZone` の外に置くことで、fallback が表示されるのは suspend したサブツリーだけになり、ボタンは表示されたまま `scope.isPending` を観測できます：

```dart
class ProfileSwitcher extends StatefulWidget {
  const ProfileSwitcher({super.key});

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  int _id = 1;

  @override
  Widget build(BuildContext context) {
    return _ProfileSwitcherBody(
      id: _id,
      onNext: () => setState(() => _id++),
    );
  }
}

class _ProfileSwitcherBody extends TransitionZoneWidget {
  const _ProfileSwitcherBody({required this.id, required this.onNext});

  final int id;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scope = TransitionZone.of(context);
    return Column(children: [
      AsyncZone(
        fallback: const CircularProgressIndicator(),
        child: ProfileCard(userId: id), // 取得中に suspend する ZoneWidget
      ),
      ElevatedButton(
        onPressed: () => scope.startTransition(onNext),
        child: Text(scope.isPending ? '読み込み中…' : '次へ'),
      ),
    ]);
  }
}
```

サブクラスを定義せずインラインで使いたい場合は、`TransitionZoneBuilder` で同じ scope を取得できます：

```dart
TransitionZoneBuilder(
  builder: (context) {
    final scope = TransitionZone.of(context);
    return Column(children: [
      AsyncZone(
        fallback: const CircularProgressIndicator(),
        child: ProfileCard(userId: id),
      ),
      ElevatedButton(
        onPressed: () => scope.startTransition(onNext),
        child: Text(scope.isPending ? '読み込み中…' : '次へ'),
      ),
    ]);
  },
)
```

`TransitionZone.of(context)` は `TransitionZoneWidget` の `build`（または `TransitionZoneBuilder` の builder）の中で呼ぶ必要があります。descendant の context から呼ぶと例外をスローするので、深い場所で使う場合は外側の `build` で取得して下位に受け渡してください。

`action` 自体が `Future` を返した場合、`startTransition` はそれを自動で track します。これにより `compute()` などの明示的な非同期処理の間、suspend する `ZoneWidget` がなくても `isPending` を true に保てます：

```dart
scope.startTransition(() async {
  final data = await api.fetchUser(id);
  final result = await compute(_expensiveTransform, data);
  setState(() => _data = result);
});
```

**挙動のメモ:**

- `isPending` は実際に suspend が発生したときだけ立ちます — descendant の `ZoneWidget` が何も throw しない no-op transition は flicker なしで静かに終わります。
- 同じ target を連打した場合、descendant の `ZoneWidget` が次のビルドで自動 supersede するので、`isPending` は最新の処理を反映します（重なっている呼び出しの和集合ではない）。Future 自体はキャンセルされません — *ライフサイクルと unmount 時の挙動* を参照。
- Async action の Future（`action` が `Future` を返す場合）は **supersede されず merge** されます — 重なる `startTransition` 呼び出しは両方とも track され、両方が resolve するまで `isPending` は true のままです。進行中の非同期処理のキャンセルは呼び出し側の責任です。
- Flutter のレンダラは同期的なので、レンダリングの中断機能や `useDeferredValue` 相当はありません — 重い CPU 処理は `compute()` / `Isolate.run` でオフロードし、deferred-value 的な挙動は `useEffect` + `useState` で組んでください。

> hooks（`useState` など）と transition scope を一つの widget に同居させたい場合は、[hooks_async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/hooks_async_zone) パッケージの `HookTransitionZoneWidget` を参照。

> **フレッシュマウントでは fallback に切り替わる。** suspend する element に過去の commit 済みビルドがない場合（リトライ直後に子に戻ったばかりの `ErrorBoundary`、新規挿入されたルートなど）、その element に対して transition は延長されません。suspend した Future は通常の Suspense として囲みの `AsyncZone` の fallback に振り分けられます。

### ライフサイクルと unmount 時の挙動

実際にアプリで動かしたときに知っておくと良い点：

- **unmount で pending な Future はキャンセルされません。** Dart の `Future`
  にキャンセルの仕組みは無いためです。element の `mounted` ガードによって
  後から完了しても黙って無視され、dispose 済みの element に対して
  `markNeedsBuild()` が呼ばれることはありませんが、HTTP リクエストなどの実際の
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

### `CustomScrollView` の中で使う

suspend する widget が sliver を返したい場合は `SliverZoneWidget` / `SliverStatefulZoneWidget` / `SliverZoneBuilder` を使います。suspend 中もスロットが有効な sliver のまま保たれます。境界の `AsyncZone` 自体は box widget のままで、`CustomScrollView` を通常どおり包んで使います。

```dart
AsyncZone(
  fallback: const CircularProgressIndicator(),
  child: CustomScrollView(
    slivers: [
      SliverZoneBuilder(
        builder: (context) {
          final items = AsyncZone.of(context).use(future);
          return SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => Text(items[i]),
          );
        },
      ),
    ],
  ),
)
```

> **Note:** `ErrorBoundary` / `ErrorZoneWidget` は box widget です。`CustomScrollView` の外（または sliver サブツリーの上位）に置いてください。fallback と escalation 経路が box widget を返すため、sliver list の中に直接ネストすることはできません。

カスタムの sliver-shaped element を作る場合（hooks や他パッケージと `ZoneElement` を組み合わせるなど）、`ZoneElement` と一緒に `SliverZoneElementMixin` を mix in します:

```dart
class MyCustomSliverElement extends StatelessElement
    with SomeMixin, ZoneElement, SliverZoneElementMixin {
  MyCustomSliverElement(super.widget);
}
```

mixin が suspend 中の placeholder を sliver-shaped なものに差し替えてくれます。

### カスタムエラーゾーン

#### `ErrorBoundary` と `ErrorZoneWidget` の使い分け

姉妹パッケージの [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary)
は `ErrorZoneWidget` を 1 つの設定可能なウィジェット（`ErrorBoundary`）に
ラップしたものです。低レベル API を直接利用する必要がなければ、こちらを使うのが
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

より細かい制御が必要な場合は、`ErrorBoundaryMixin` を mixin して `ErrorZoneElement` を持つカスタム element を作成：

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

`ErrorZoneWidget`（または `ErrorZoneElement` を使った任意のウィジェット）を入れ子にした場合、内側のフォールバック内で throw されたエラーは外側のエラーゾーンにエスカレートします（React の error boundary の意味論と同じ）。対象は次のとおりです：

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

| プロパティ | 型       | 説明                                         |
| ---------- | -------- | -------------------------------------------- |
| `fallback` | `Widget` | 非同期処理が保留中の間に表示するウィジェット |
| `child`    | `Widget` | メインコンテンツウィジェット                 |

**メソッド:**

- `AsyncZone.of(context)` - `use()` 経由で future を消費するための `AsyncZoneScope` を返します。

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

### SliverZoneWidget / SliverStatefulZoneWidget / SliverZoneBuilder

`ZoneWidget` / `StatefulZoneWidget` / `ZoneBuilder` の sliver 版。suspend する widget を `CustomScrollView` の直下に置く場合に使用します。境界の `AsyncZone` 自体は box widget のまま — [`CustomScrollView` の中で使う](#customscrollview-の中で使う) を参照。

### TransitionZoneWidget / TransitionZoneBuilder

transition を調停するウィジェット。descendant の状態更新で suspend しても `AsyncZone` の fallback に切り替えず直前の subtree を画面に残します（React `useTransition` 相当）。

- transition scope を持たせる stateless widget を作る場合は `TransitionZoneWidget` を継承。インライン記述には `TransitionZoneBuilder` を使用。
- `build`（または builder）の中で `TransitionZone.of(context)` を呼んで scope を取得します。`isPending` が進行中かどうかを示し、`startTransition(action)` で transition を起動します。`action` が `Future` を返した場合は自動で track されます。
- 使い方は [Transition（useTransition ライク）](#transitionusetransition-ライク) を参照。

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
- `use()` による Future インスタンス同一性ベースのキャッシュ — 同じインスタンスについて future は 1 回だけ実行される
- 関心の分離がより明確
- 合成しやすい構造

## ライセンス

このプロジェクトは BSD 3-Clause License の下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## インスピレーション

このパッケージは以下からインスパイアされています：

- 非同期処理のための React の Suspense
- エラーハンドリングのための React の Error Boundary
- Flutter の宣言的 UI 原則
