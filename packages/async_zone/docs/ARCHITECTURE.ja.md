# AsyncZone 設計仕様書

[English](ARCHITECTURE.md) | **日本語**

## 概要

AsyncZone は、React の Suspense ライクな非同期処理と Error Boundary 機能を提供する Flutter ライブラリです。build メソッドから `Future` オブジェクトをスローし、上位で捕捉してローディング中のフォールバック UI を表示できます。

## アーキテクチャ

### コアコンポーネント

```
┌─────────────────────────────────────────────────────────┐
│                     Application                         │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐    │
│  │      ErrorZoneWidget (ErrorBoundary)            │    │
│  │  ┌───────────────────────────────────────────┐  │    │
│  │  │       AsyncZone (Suspense)                │  │    │
│  │  │  ┌─────────────────────────────────────┐  │  │    │
│  │  │  │        ZoneWidget                   │  │  │    │
│  │  │  │  - Throws Future from build()       │  │  │    │
│  │  │  │  - Handles async operations         │  │  │    │
│  │  │  └─────────────────────────────────────┘  │  │    │
│  │  └───────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### モジュール構造

```
lib/src/
├── async/                   # AsyncZone (Suspense) 実装
│   ├── zone.dart            # 公開API
│   ├── zone_provider.dart   # InheritedWidget & Element
│   └── zone_scope.dart      # インターフェース定義
├── error/                   # Error Boundary 実装
│   ├── zone.dart            # ErrorZoneWidget基底クラス
│   ├── zone_element.dart    # ErrorZoneElement mixin
│   ├── zone_controller.dart # 状態管理コントローラー
│   └── zone_provider.dart   # エラー伝播プロバイダー
├── foundation/
│   ├── empty.dart           # プレースホルダー用空ウィジェット（box）
│   └── sliver_empty.dart    # プレースホルダー用空 sliver
├── transition/                  # Transition（useTransition ライク）実装
│   ├── transition.dart          # 公開 API とウィジェット
│   ├── transition_provider.dart # InheritedWidget と Element mixin
│   └── transition_scope.dart    # Scope / Bridge インターフェース
├── sliver_zone.dart         # sliver 版 ZoneWidget と mixin
├── zone_element.dart        # ZoneElement基底
└── zone.dart                # ZoneWidget基底
```

## 設計パターン

### 1. 非同期処理（Suspense ライク）

ウィジェットが`Future`オブジェクトをスローし、`ZoneElement`が捕捉して親の`AsyncZone`で処理します。

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw fetchData(); // Futureが完了するまでサスペンド
  }
}
```

**主要メカニズム**: ZoneElement がスローされた Future を捕捉し、AsyncZone にフォールバック表示を通知、完了時に再ビルドします。

### 2. Expando によるキャッシュ管理

弱参照を使用した自動ガベージコレクション：

```dart
final _cache = Expando<Object>('AsyncZone cache');
final _errors = Expando<Object>('AsyncZone errors');
```

**利点**:

- Future が参照されなくなったときの自動 GC
- メモリリークなし
- 手動クリーンアップ不要

**トレードオフ**: 手動でのキャッシュクリアは不可（設計意図）。

### 3. カスタムエラーゾーン

React ライクなライフサイクルメソッドでカスタムエラーハンドリングを作成：

```dart
class MyErrorZone extends ErrorZoneWidget<({Object? error})> {
  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    log(error);
  }

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) {
    return (error: error);
  }

  @override
  Widget build(BuildContext context) {
    return state.error != null ? ErrorView(state.error) : child;
  }
}
```

**コントローラーパターン**: Widget がコントローラーを保持（一時的）、Element がアタッチ（永続的）。

> **Note:** よりシンプルなエラーバウンダリー実装については、別パッケージ [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary) をご確認ください。

### 4. Sliver 版バリアント

`AsyncZone` は box widget（子を `Stack`/`Visibility` で包む）ですが、suspend する widget が `CustomScrollView` の中で `RenderSliver` を返す必要があるケースがあります。sliver 版 `SliverZoneWidget` / `SliverStatefulZoneWidget` / `SliverZoneBuilder` は `build()` から sliver を返しつつ `ZoneElement` を mix in しています。

**実装。**

- `ZoneElement.emptyPlaceholder` は protected な getter で、デフォルトは `const Empty()`。このフレームで例外が fallback に振られた時に返されます。
- `SliverZoneElementMixin on ZoneElement` がそれを `const SliverEmpty()`（`SliverGeometry.zero` の leaf `RenderSliver`）に差し替えます。
- `StatelessSliverZoneElement` / `StatefulSliverZoneElement` がこの mixin を mix in しており、外部パッケージ（`hooks_async_zone` や独自の `ConsumerStatefulElement` 組み合わせなど）も同じ mixin を活用できます。

境界自体は box のままです。`ErrorBoundary` / `ErrorZoneWidget` や囲みの `AsyncZone` は box コンテキスト（`CustomScrollView` の外側もしくは上位）に配置します。sliver レベルの粒度のエラー境界は提供していません。

### 5. Transition（useTransition ライク）

`TransitionZoneWidget` は React の `useTransition` を模倣しています。transition 進行中は、descendant がスローした Future は囲みの `AsyncZone` の fallback ではなく transition によって追跡され、直前の subtree が画面に残ったまま `isPending` が同じフレームに反映されます。

**実装。**

- **Bridge プロトコル。** `TransitionZoneBridge` は追跡を特定の非同期フレームワークから切り離します。`ZoneElement` は Future の出現・差し替えに合わせて `track` / `supersede` を呼びます（Future 自体はキャンセルされず、追跡から外されるだけ）。`action` が `Future` を返した場合 `startTransition` が自動 track し、`compute()` の結果など独自の Future も呼び出し側から `track` できます。
- **2 段階リビルド。** `startTransition` は `action` を同期実行し、`performRebuild` で descendant に Future を track させた上で、`_tracked` が公開済み `_isPending` と食い違えばもう 1 度リビルドして同フレームでフラグを表面化させます。何も track されなければ transition は静かに終了します。React の render-then-decide なコミットモデルと同じ挙動です。
- **フレッシュマウント時のフォールバック。** `ZoneElement._hasCommittedBuild` が transition の延長を通過させるゲートです。`false` の間は保持すべき過去の subtree がないため、suspend した Future は `AsyncZone` の fallback に振り分けられます。境界に保持するものがない場合に通常の Suspense に格下げする React の挙動と一致します。

`TransitionZone.of(context)` は scope を持つ element 自身の build コンテキストで呼ぶ必要があります。深い場所で使う場合は外側の `build` で取得して下位に受け渡してください。2 段階リビルドはトリガーのリビルドチェーンが scope を持つ element を通過したときにのみ descendant に届きます。

## 公開 API 一覧

| 型                      | 役割                                                                  |
| ----------------------- | --------------------------------------------------------------------- |
| `AsyncZone`             | 境界ウィジェット。子孫が suspend している間 `fallback` を描画。       |
| `AsyncZoneScope`        | `AsyncZone.of(context)` の戻り値。`use<T>(future)` を提供。           |
| `ZoneWidget`            | `Element` が `ZoneElement` を mixin した `StatelessWidget`。          |
| `StatefulZoneWidget`    | 上記の `StatefulWidget` 版。                                          |
| `ZoneBuilder`           | サブクラス化せずに `ZoneWidget` をインライン記述する便利ウィジェット。 |
| `SliverZoneWidget` / `SliverStatefulZoneWidget` / `SliverZoneBuilder` | 上記の sliver 版。`CustomScrollView` 内に直接配置するときに使用。 |
| `SliverZoneElementMixin` | `on ZoneElement`。suspend 中の placeholder を `SliverEmpty` に差し替える。カスタム sliver 用 element を組むときに mix in する。 |
| `ErrorZoneWidget<T>`    | `getDerivedStateFromError` / `componentDidCatch` を持つカスタム境界。 |
| `ErrorBoundaryMixin<T>` | 同じライフサイクルを mixin として提供（独自階層用）。                  |
| `TransitionZoneWidget` / `TransitionZoneBuilder` | 自身の element が transition を調停するウィジェット（React `useTransition` ライク）。 |
| `TransitionZoneScope`   | `TransitionZone.of(context)` の戻り値。`isPending` と `startTransition` を提供。 |
| `TransitionZoneBridge`  | `TransitionZone.bridgeOf` で取得。`ZoneElement` 等の外部トラッカーが `track` / `supersede` で transition の寿命を延ばすためのインターフェース。 |
| `TransitionZoneElement` | `on ComponentElement`。任意の element 型に transition の調停機能を組み込む mixin。外部パッケージ（`hooks_async_zone` 等）からも再利用される。 |

シグネチャやユーザ向けサンプルは README を参照してください。本ドキュメントは
API リファレンスではなく、設計の説明書です。

## エラーハンドリング戦略

| シナリオ               | ErrorZoneWidget 有無 | 動作                                   |
| ---------------------- | -------------------- | -------------------------------------- |
| 同期エラー             | あり                 | ErrorZoneWidget が捕捉                 |
| 同期エラー             | なし                 | 再スロー（Flutter が処理）             |
| 非同期エラー（Future） | あり                 | Future 完了後に ErrorZoneWidget が捕捉 |
| 非同期エラー（Future） | なし                 | 保存され、次のビルドで再スロー         |

## パフォーマンス考慮事項

### メモリ管理

- **Expando**: 自動 GC によりメモリリーク防止
- **unmount()**: タスク参照のクリア

### レンダリング最適化

- **子の更新スキップ**: ローディング中の ErrorWidget フラッシュを防止（FAQ Q1 参照）
- **ダブルリビルド**: 即座の状態反映（FAQ Q6 参照）

### ビルド最適化

```dart
// ✅ 良い例: Futureインスタンスを再利用
final _dataFuture = fetchData();
throw _dataFuture;  // キャッシュヒット

// ❌ 悪い例: ビルド毎に新しいFutureを作成
throw fetchData();  // キャッシュミス
```

## よくある質問（FAQ）

### Q1: タスク実行中に`updateChild`で子の更新をスキップする理由は？

AsyncZone がフォールバックを表示する前に ErrorWidget が 1 フレームだけ表示されるのを防ぐため。

**スキップありのタイムライン**:

- フレーム N: Future スロー → 古い子を保持（フラッシュなし）
- フレーム N+1: AsyncZone がフォールバックを表示

### Q2: ビルド毎に`controller.attach()`を呼ぶ理由は？

Element は永続的だが、Widget は頻繁に再ビルドされます。新しい Widget には新しいコントローラーがあるため、Element は再アタッチが必要です。

**ライフサイクル**:

- Element: 一度作成され、unmount まで存続
- Widget: リビルド毎に新しいインスタンス

### Q3: `markNeedsBuild()`を直接呼ばず`postFrameCallback`を使う理由は？

`showFallback()`を呼び出す子ウィジェットがまだビルド中です。同期的な`markNeedsBuild()`は以下を引き起こします：

```
setState() or markNeedsBuild() called during build
```

`postFrameCallback`は現在のフレームが完了するまで待ちます。

### Q4: `use()`がエラーをキャッシュしない理由は？

**関心の分離**:

- `use()`: シンプルなキャッシュ検索、Future をスロー
- `showFallback()`: 完全な状態管理（成功 + エラー）

エラーキャッシュは`showFallback()`の責務です。これによりエラーハンドリングロジックが集中化され、理解しやすくなります。

### Q5: `performRebuild()`で 2 回リビルドする理由は？

同じフレーム内でエラー状態の変化を即座に反映するため。

**ダブルリビルドなし**: エラー → 古い UI（1 フレーム） → フォールバック
**ダブルリビルドあり**: エラー → フォールバック（同じフレーム）

これによりエラー発生時の視覚的な遅延を防ぎます。

### Q6: `startTransition` の action を同期実行する理由は？

`action` を遅延させると次のリビルドが古い state のまま実行されます。例えば `ErrorBoundary.onReset` のコールバックを遅延された `startTransition` 経由で呼ぶと、reset が反映される前に直前のエラー状態の subtree が再レンダリングされ、新しい state を反映するのにもう 1 回リビルドが必要になります。

### Q7: transition がフレッシュマウントを延長しない理由は？

transition 中の Future 処理は直前の subtree を残すために機能するため、残すべきものが必要です。フレッシュマウント（リトライで子に戻ったばかりの `ErrorBoundary`、新規挿入されたルートなど）では保持するものがないので、suspend した Future は通常の Suspense として `AsyncZone` の fallback に振り分けられます。`ZoneElement._hasCommittedBuild` が element ごとのゲートです。

### Q8: React の `useTransition` との比較は？

観測可能な挙動は一致します（前の UI が残る、`isPending` が進行中の処理を反映、no-suspend transition は静かに終了する、同一 target の連打は auto-supersede）。一方で内部実装は異なります: Flutter のレンダラは同期的なのでレンダリングの中断機能はなく、`useDeferredValue` 相当もなく、async action の Future は supersede ではなく merge されます（Dart の `Future` はキャンセルできないため、副作用がまだ実行中の可能性がある状態で tracking から外すのは安全ではない）。

## 関連パターン

### React Suspense

- render から promise をスロー
- ローディング中のフォールバック UI
- 自動的な状態管理

### Flutter パターン

- **InheritedWidget**: コンテキスト伝播
- **Element ライフサイクル**: 永続的な状態
- **Mixin 合成**: 再利用可能な動作

## まとめ

AsyncZone は、Flutter における宣言的な非同期処理とエラーハンドリングを提供します：

1. **シンプルさ**: Future をスロー、境界で捕捉
2. **安全性**: 自動メモリ管理
3. **パフォーマンス**: 最適化されたレンダリング
4. **組み合わせ可能性**: 非同期処理とエラー境界の組み合わせ

この設計は、Flutter のパフォーマンス特性を維持しながら、開発者体験を優先しています。
