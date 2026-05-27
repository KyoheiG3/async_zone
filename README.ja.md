<img width="1600" height="640" alt="async_zone Logo" src="https://github.com/user-attachments/assets/9b85aa6e-8137-4994-a757-14b0060e4d53" />

# async_zone

[English](README.md) | **日本語**

React の **Suspense**、**Error Boundary**、**useTransition** の primitives を Flutter に持ち込む monorepo です。`FutureBuilder` の入れ子や手動のローディング状態管理なしに、宣言的に非同期 UI を組めます。

React では、コンポーネントを suspend させるために render で promise を `throw` し、それを `<Suspense>` でラップして fallback を表示します。`<ErrorBoundary>` でエラーから回復し、`useTransition` の `startTransition()` を呼べば、新しい state の準備中も前の UI を画面に残せます。この 4 つのパッケージは、同じ primitives を Flutter で提供します。API は意図的に、**ほぼそのまま対応づくマッピング** にしてあります：

| React                                                 | この monorepo                                                                                                        |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `<Suspense fallback={...}>`                           | `AsyncZone(fallback: ...)`                                                                                           |
| `use(promise)`（React 19）                            | `AsyncZone.of(context).use(future)`（または `useAsyncZone().use(future)`）                                           |
| `<ErrorBoundary>`                                     | `ErrorBoundary(builder: ..., child: ...)`                                                                            |
| `componentDidCatch` / `getDerivedStateFromError`      | `ErrorZoneWidget<T>` の同名ライフサイクル                                                                            |
| `useTransition` / `startTransition`                   | `TransitionBoundary` + `TransitionZone.of(context).startTransition(...)`                                             |
| `useTransition` の `isPending`                        | `TransitionZone.of(context).isPending`                                                                               |
| React Hooks（`useState`、`useEffect` など）+ Suspense | [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) + `hooks_async_zone`（`HookZoneWidget`、`useAsyncZone()`） |

zone 対応ウィジェットの `build()` 内で `Future` を throw すれば、外側の `AsyncZone` が fallback を表示し、エラーは最も近い `ErrorBoundary` に伝播し、さらに外側に `TransitionBoundary` があれば、fallback をちらつかせる代わりに前のサブツリーをそのまま画面に残せます。挙動は React と同じで、変わるのはキーワードだけです（`Promise` ではなく `Future`）。

## React との制約と差分

API の形は React に揃えていますが、Flutter のレンダリングモデル自体は React とは異なります。この **2 つのアーキテクチャ上の違い** から、ほかの差分はすべて生じています：

- **描画の中断ができない。** React の `useTransition` は進行中の render をツリーの途中で破棄できます（concurrent rendering）。Flutter のレンダラは同期実行なので、`TransitionBoundary` は見た目の部分（前のサブツリーを残す、`isPending` を立てる）を **シミュレートしているだけ** で、既に走り始めた処理を中断することはできません。同じ理由で `useDeferredValue` 相当の仕組みも提供できません（defer できるタイムスライシングがそもそも存在しないため）。
- **`Future` をキャンセルできない。** Dart の `Future` には cancel primitive がありません。suspend 中のサブツリーが unmount されたり、transition が進行中の fetch を新しいもので置き換えても、bridge は future の _トラッキングを止める_ だけで、裏で動いている I/O は完了するまで走り続けます。実際にキャンセルしたい場合は `package:async` の `CancelableOperation` を使ってください。

`use(future)` 自体は identity-based で、これは React の `use(promise)` と同じです。リビルド間で同じ `Future` インスタンスを渡してください（`late final`、`useMemoized`、親 state など）。そうしないと永久に suspend します。クエリキーで「同じキー → 同じ結果」のような **値ベースのキャッシュ** が欲しい場合は、その上に state-management ライブラリを重ねます。[`fquery_sample`](examples/fquery_sample) / [`tanstack_query_sample`](examples/tanstack_query_sample) / [`riverpod_sample`](examples/riverpod_sample) のサンプルが小さな bridge 実装を示しており、これは React 側で `use()` と TanStack Query / SWR が分担しているのと同じ構図です。

## パッケージ

| パッケージ                                            | 説明                                                                                                                                                                         |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`async_zone`](packages/async_zone)                   | コア。`AsyncZone`、`ZoneWidget` / `StatefulZoneWidget` / `SliverZoneWidget` / `ZoneBuilder`、および `ErrorZoneWidget` ライフサイクル基底クラス。他はすべてこれに依存します。 |
| [`error_boundary`](packages/error_boundary)           | 高レベルな `ErrorBoundary` ウィジェット — `builder(context, error, reset)`、`onError` / `onReset` コールバック、`resetKeys` による自動リセット、手動の `showBoundary`。      |
| [`transition_boundary`](packages/transition_boundary) | React の `useTransition` スタイルのトランジション。サブツリーを `TransitionBoundary` でラップすると、配下の suspend が外側の `AsyncZone` fallback を出さずに吸収されます。   |
| [`hooks_async_zone`](packages/hooks_async_zone)       | `flutter_hooks` との統合 — `HookZoneWidget`、`useAsyncZone()`、sliver / error バリエーション。既に hooks を使っているコードベース向け。                                      |

## クイックスタート

必要なものだけ入れてください。多くのアプリは、まず `async_zone` + `error_boundary` から始めるのがおすすめです：

```sh
flutter pub add async_zone error_boundary
# 必要に応じて追加：
flutter pub add transition_boundary
flutter pub add hooks_async_zone
```

最小例 — エラー fallback 付きで suspend するデータカード：

```dart
import 'package:async_zone/async_zone.dart';
import 'package:error_boundary/error_boundary.dart';
import 'package:flutter/material.dart';

class UserCard extends ZoneWidget {
  const UserCard({super.key, required this.future});

  final Future<User> future;

  @override
  Widget build(BuildContext context) {
    // future が resolve するまで throw — 外側の AsyncZone が fallback を表示します。
    // エラーは外側の ErrorBoundary に伝播します。
    final user = AsyncZone.of(context).use(future);
    return Text(user.name);
  }
}

// 使い方
final userFuture = fetchUser(1); // 同じ Future インスタンスをリビルド間で保持

ErrorBoundary(
  builder: (context, error, reset) => ErrorView(error: error, onRetry: reset),
  child: AsyncZone(
    fallback: const CircularProgressIndicator(),
    child: UserCard(future: userFuture),
  ),
)
```

## どこから始めるか

| やりたいこと                                                                       | 追加するもの                                                      |
| ---------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Suspense + `use()` だけ                                                            | `async_zone`                                                      |
| すぐ使える `ErrorBoundary` ウィジェット（自前で `ErrorZoneWidget` を書くより推奨） | `async_zone` + `error_boundary`                                   |
| React `useTransition` スタイルの「新しい state が suspend する間も前の UI を残す」 | `+ transition_boundary`                                           |
| 既に `flutter_hooks` を使っている                                                  | `+ hooks_async_zone`（`HookZoneWidget`、`useAsyncZone()` を提供） |

各パッケージの README に、詳細な API リファレンス、よくある落とし穴（特に `use()` の identity-based キャッシュ周り）、より長い例が載っています。

## アーキテクチャ

すべては `async_zone` の `ZoneElement` mixin という単一の primitive の上に組まれています。これを mixin した任意の `Element` が、`build()` 中に throw された `Future` や `Object` を捕まえ、`InheritedWidget` ルックアップで適切な provider に振り分けます：

- throw された `Future` は `AsyncZoneProvider`（`AsyncZone` が用意）に渡される → fallback 描画、future インスタンスの同一性をキーにした結果キャッシュ。
- `Object` エラーは `ErrorZoneProvider`（`ErrorZoneWidget` / `ErrorBoundary` が用意）に渡される → fallback builder、外側のエラーゾーンへの伝播。
- transition がアクティブな間は、future は async fallback の代わりに `TransitionZoneProvider`（`TransitionBoundary` が用意）に登録される → 前のサブツリーが画面に残り、`isPending` が立つ。

合成は 2 つのレイヤーで行われます：`Element` の mixin 合成（例：`HookZoneWidget` = `HookElement` + `ZoneElement`、riverpod サンプルの `ConsumerZoneWidget` = `ConsumerStatefulElement` + `ZoneElement`）と、`InheritedWidget` のネスト（zone / boundary / transition はネスト可能で、React の boundary と同じく「外側が内側で扱えないものを拾う」という挙動になります）。

## サンプル

[`examples/`](examples) ディレクトリに 6 つの実行可能なサンプルがあります。前半 3 つはコアパッケージを直接デモし、後半 3 つは state-management ライブラリが小さな bridge 実装で同じ Suspense パターンに乗れることを示しています：

| サンプル                                                  | デモする内容                                                                                                 |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| [`async_zone_sample`](examples/async_zone_sample)         | リファレンス実装 — `AsyncZone` + `use()` + `ErrorBoundary` + `TransitionBoundary` を `hooks_async_zone` で。 |
| [`stateful_zone_sample`](examples/stateful_zone_sample)   | 同じ UX を素の `StatefulZoneWidget` で（Hooks に依存しない版）。                                             |
| [`sliver_zone_sample`](examples/sliver_zone_sample)       | 同じ UX を `CustomScrollView` の中に置き、`SliverStatefulZoneWidget` を使った版。                            |
| [`fquery_sample`](examples/fquery_sample)                 | `fquery` bridge — `useAsyncZoneQuery` フックで TanStack スタイルのキャッシュに対し Suspense + `use()`。      |
| [`tanstack_query_sample`](examples/tanstack_query_sample) | `tanstack_query` bridge — `fquery_sample` と同じパターンを TanStack Query の Dart 移植に対して。             |
| [`riverpod_sample`](examples/riverpod_sample)             | Riverpod bridge — `ConsumerZoneWidget`（`ConsumerStatefulElement` + `ZoneElement`）+ `watchOrSuspend`。      |

fquery / tanstack / riverpod のサンプルは、任意のリアクティブ state ライブラリに Suspense を載せるリファレンス実装としても有用です。bridge はだいたい 60 行前後で書けます。

## 開発

このリポジトリは Dart の workspace（[`pubspec.yaml`](pubspec.yaml)）で、すべてのパッケージとサンプルが単一の lockfile から解決されます：

```sh
flutter pub get              # workspace 全体を解決
flutter test                 # 任意のパッケージディレクトリで
```

各サンプルは、そのディレクトリに `cd` してから `flutter run` で起動できます。

## インスピレーション

- React の [Suspense](https://react.dev/reference/react/Suspense) と [`use()`](https://react.dev/reference/react/use) フック
- React の [Error Boundary](https://react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary) と [`react-error-boundary`](https://github.com/bvaughn/react-error-boundary)
- React の [`useTransition`](https://react.dev/reference/react/useTransition)

## ライセンス

BSD 3-Clause — [LICENSE](LICENSE) を参照してください。
