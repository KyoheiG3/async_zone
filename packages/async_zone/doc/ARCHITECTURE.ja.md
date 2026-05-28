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
├── transition/              # Transition 統合インターフェース（bridge のみ）
│   ├── zone_provider.dart   # TransitionZoneProvider (InheritedWidget)
│   └── zone_scope.dart      # TransitionZoneBridge interface
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

> **Note:** よりシンプルなエラーバウンダリー実装については、別パッケージ [async_error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_error_boundary) をご確認ください。

### 4. Sliver 版バリアント

`AsyncZone` は box widget（子を `Stack`/`Visibility` で包む）ですが、suspend する widget が `CustomScrollView` の中で `RenderSliver` を返す必要があるケースがあります。sliver 版 `SliverZoneWidget` / `SliverStatefulZoneWidget` / `SliverZoneBuilder` は `build()` から sliver を返しつつ `ZoneElement` を mix in しています。

**実装。**

- `ZoneElement.emptyPlaceholder` は protected な getter で、デフォルトは `const Empty()`。このフレームで例外が fallback に振られた時に返されます。
- `SliverZoneElementMixin on ZoneElement` がそれを `const SliverEmpty()`（`SliverGeometry.zero` の leaf `RenderSliver`）に差し替えます。
- `StatelessSliverZoneElement` / `StatefulSliverZoneElement` がこの mixin を mix in しており、外部パッケージ（`hooks_async_zone` や独自の `ConsumerStatefulElement` 組み合わせなど）も同じ mixin を活用できます。

境界自体は box のままです。`ErrorBoundary` / `ErrorZoneWidget` や囲みの `AsyncZone` は box コンテキスト（`CustomScrollView` の外側もしくは上位）に配置します。sliver レベルの粒度のエラー境界は提供していません。

### 5. Transition との統合

`transition` モジュールが公開するのは統合用のインターフェースのみです — 契約となる `TransitionZoneBridge` と、それを descendant に publish する `InheritedWidget` である `TransitionZoneProvider` の 2 つだけです。`ZoneElement` は build 中にこれらを参照し、上位に存在する transition coordinator と協調します。

**`ZoneElement` 側の統合。**

- build 中に `ZoneElement` は `TransitionZoneProvider.maybeOf(context)` で最寄りの bridge を取得します。
- descendant が Future をスローしたとき、`ZoneElement` は `bridge.inTransition` を参照します。`true` かつ以前に build を成功させていれば、Future を `bridge.track(future)` で transition に登録し、上位の `AsyncZone` の fallback には渡しません（直前の subtree がそのまま残ります）。
- 古い Future が新しい Future に差し替えられた場合 (state 変更により suspend する Future が変わった場合など)、`ZoneElement` は `bridge.supersede(oldFuture)` を呼んで追跡対象から外します。Future 自体はキャンセルされず、バックグラウンドで実行が継続します。
- `ZoneElement._hasCommittedBuild` は transition の延長を許可するゲートです。`false` の場合（フレッシュマウント時）は、保持すべき直前の subtree が存在しないため、suspend した Future は通常の Suspense として `AsyncZone` の fallback に振り分けられます。保持対象がない場合に Suspense へ downgrade する React の挙動と一致します。

> **Note:** `async_zone` 自体は transition coordinator を提供しません。React の `useTransition` ライクに「新しい状態が suspend している間も直前の subtree を画面に残す」挙動が欲しい場合は、別パッケージの [async_transition_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_transition_boundary) を参照してください。

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
| `TransitionZoneBridge`  | `ZoneElement` が transition の寿命を延ばすために呼ぶ interface (`track` / `supersede`)。`TransitionZoneProvider.maybeOf` 経由で取得。 |
| `TransitionZoneProvider` | descendant に `TransitionZoneBridge` を publish する `InheritedWidget`。`async_transition_boundary` の `TransitionBoundary` 等の実装が構築する。 |

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
- **ダブルリビルド**: 即座の状態反映（FAQ Q5 参照）

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

### Q6: transition がフレッシュマウントを延長しない理由は？

transition 中の Future 処理は直前の subtree を残すために機能するため、残すべきものが必要です。フレッシュマウント（リトライで子に戻ったばかりの `ErrorBoundary`、新規挿入されたルートなど）では保持するものがないので、suspend した Future は通常の Suspense として `AsyncZone` の fallback に振り分けられます。`ZoneElement._hasCommittedBuild` が element ごとのゲートです。

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
