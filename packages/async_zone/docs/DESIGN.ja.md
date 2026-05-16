# AsyncZone 設計仕様書

[English](DESIGN.md) | **日本語**

## 概要

AsyncZone は、React の Suspense ライクな非同期処理と Error Boundary 機能を提供する Flutter ライブラリです。build メソッドから`Future`オブジェクトをスローし、上位で捕捉してローディング中のフォールバック UI を表示できます。

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
│   ├── frozen_future.dart   # freeze オプトイン用の Future ラッパ
│   ├── zone.dart            # 公開API
│   ├── zone_provider.dart   # InheritedWidget & Element
│   └── zone_scope.dart      # インターフェース定義
├── error/                   # Error Boundary 実装
│   ├── zone.dart            # ErrorZoneWidget基底クラス
│   ├── zone_element.dart    # ErrorZoneElement mixin
│   ├── zone_controller.dart # 状態管理コントローラー
│   └── zone_provider.dart   # エラー伝播プロバイダー
├── foundation/
│   └── empty.dart           # プレースホルダー用空ウィジェット
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

**コントローラーパターン**: Widget がコントローラー保持（一時的）、Element がアタッチ（永続的）。

> **Note:** よりシンプルなエラーバウンダリー実装については、別パッケージ [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary) をご確認ください。

### 4. Freeze 機構（transition 風の差し替え）

`AsyncZoneScope.use()` はオプションで `freeze: true` フラグを受け付けます。これを指定すると、新しい future が pending の間 `AsyncZone` は **fallback に切り替えるかわりに直前の subtree を画面に残し続けます**。React 19 の `useTransition` の fallback 抑制に最も近い挙動です。

**素直な移植が成立しない理由。** React の transition は **render フェーズと commit フェーズの分離** が前提です。低優先度の render が「裏で」新しいツリーを構築し続け、コミット済みの旧 UI は画面に残り続け、suspend が解決した瞬間にアトミックに差し替わる、という仕組みです。Flutter の build は同期で commit と一体なので、「画面に出さずに裏で build する」概念がそもそも存在しません。そこで採っている割り切りは：**freeze 中は新しい subtree を build しようとせず、差し替え自体を止める** というものです。

**実装。**

- `FrozenFuture<T>`（`async/frozen_future.dart`）は `Future<T>` をラップする型で、`use()` が `freeze: true` で呼ばれたときに throw します。`Future<T>` を実装しているので既存の `on Future catch` でも拾えますが、`ZoneElement` はより具体的な `on FrozenFuture catch` で受け止めて、`AsyncZoneProviderScope.showFallback(future, freeze: true)` にフラグを伝搬します。
- `AsyncZoneProviderElement._tasks` は `Map<Future, bool>` で、各 pending future に対する freeze フラグを保持します。
- `AsyncZoneProviderElement.updateChild` は `_tasks` のいずれかが `freeze == true` のとき、`super.updateChild` を呼ばずに既存の子 element をそのまま返します。この short-circuit が「旧 UI を画面に残す」実体です。

**限界。**

- `isPending` 相当をトリガーと同じフレームに反映できません。freeze フラグは future を throw する build の最中に確定するので、それを読みたい上流 widget はすでに古い値で build を済ませています。（React の `useTransition` は `isPending = true` を高優先度レーンで先に commit するのでこの順序逆転が起きません。）
- freeze 中は AsyncZone 配下への top-down 伝播が止まります。旧 subtree を画面に残すには、`AsyncZone` 経由で新しい widget config を降ろさない設計が必要だからです。subtree 内の `Listenable` 由来の再 build は引き続き動きますが、suspend している widget 自身は future が解決するまで表示を更新できません。
- 実用的には、キャッシュ層の方が同じ UX をもっと柔軟に提供できます。Riverpod や fquery のようなライブラリは前回データと `isFetching` フラグを直接公開するので、build 時の freeze は不要です。freeze フラグの主な利用シーンは Suspense pure な構成や単純なケースです。利用パターンは README の `useFreezing` 例を参照してください。

## 公開 API 一覧

| 型                      | 役割                                                                  |
| ----------------------- | --------------------------------------------------------------------- |
| `AsyncZone`             | 境界ウィジェット。子孫が suspend している間 `fallback` を描画。       |
| `AsyncZoneScope`        | `AsyncZone.of(context)` の戻り値。`use<T>(future)` を提供。           |
| `ZoneWidget`            | `Element` が `ZoneElement` を mixin した `StatelessWidget`。          |
| `StatefulZoneWidget`    | 上記の `StatefulWidget` 版。                                          |
| `ZoneBuilder`           | サブクラス化せずに `ZoneWidget` をインライン記述する便利ウィジェット。 |
| `ErrorZoneWidget<T>`    | `getDerivedStateFromError` / `componentDidCatch` を持つカスタム境界。 |
| `ErrorBoundaryMixin<T>` | 同じライフサイクルを mixin として提供（独自階層用）。                  |

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
4. **組み合わせ可能性**: 非同期とエラー境界のミックス

この設計は、Flutter のパフォーマンス特性を維持しながら、開発者体験を優先しています。
