# transition_boundary

[English](README.md) | **日本語**

[async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) に React の `useTransition` のような transition を提供する Flutter パッケージです。`TransitionBoundary` でサブツリーをラップしておくと、新しい非同期状態が準備されている間、囲みの `AsyncZone` の fallback にちらつくことなく、直前のコンテンツを画面に残し続けられます。

## 機能

- 🔀 **TransitionBoundary**: 新しい subtree が suspend している間も直前の UI を残す `useTransition` ライクな状態更新
- ⏳ **isPending フラグ**: subtree の任意の場所から購読して、進行中のサブツリーを暗くしたり、ボタンの状態やラベルを切り替えたりできる
- ⚙️ **自動 track**: `startTransition` は descendant の suspend に加え、`Future` を返す action（`compute()` など）も自動で track
- 🪶 **シンプルな API**: 一度 `TransitionBoundary` でラップしておけば、subtree のどこからでも `TransitionZone.of(context)` でトリガーできる

## インストール

```bash
flutter pub add transition_boundary
```

または、`pubspec.yaml` に手動で追加：

```yaml
dependencies:
  transition_boundary:
```

その後、以下を実行：

```bash
flutter pub get
```

## クイックスタート

`TransitionBoundary` は **transition 中にフリーズさせたい `ZoneWidget` の上** に配置します。transition 進行中は、descendant が suspend しても囲みの `AsyncZone` の fallback には切り替わらず、その Future を boundary が代わりに追跡してくれるため、直前の subtree が画面に残ります。

典型的には `AsyncZone` の上に `TransitionBoundary` を置き、トリガーをその間に挟みます。これは技術要件ではありません（bridge の lookup は `ZoneWidget` との位置関係しか気にしません）が、トリガーを `AsyncZone` の fallback の影響範囲外に置けるメリットがあります — 新規マウントや `ErrorBoundary` のリトライ後など、まだコミットされていないサブツリーに対しては transition を延長できず、`AsyncZone` の fallback が通常どおり発火するためです。トリガー側はマウントされたまま `scope.isPending` を読んでボタンを無効化したり、進行中のビューを暗くしたりできます：

```dart
import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:transition_boundary/transition_boundary.dart';

class ProfileSwitcher extends StatefulWidget {
  const ProfileSwitcher({super.key});

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  int _id = 1;

  @override
  Widget build(BuildContext context) {
    return TransitionBoundary(
      child: Builder(
        builder: (context) {
          final scope = TransitionZone.of(context);
          return Column(children: [
            AsyncZone(
              fallback: const CircularProgressIndicator(),
              child: ProfileCard(userId: _id), // 取得中に suspend する ZoneWidget
            ),
            ElevatedButton(
              onPressed: () => scope.startTransition(() {
                setState(() => _id++);
              }),
              child: Text(scope.isPending ? '読み込み中…' : '次へ'),
            ),
          ]);
        },
      ),
    );
  }
}
```

`TransitionZone.of(context)` は最寄りの `TransitionBoundary` を `InheritedWidget` 経由で解決するため、subtree のどの build context からでも呼び出せます。外側の `build` で scope を取得して下に渡す必要はありません。boundary の有無が分からない場面では `TransitionZone.maybeOf(context)` を使ってください。

## コアコンセプト

### transition の仕組み

`TransitionBoundary` は `async_zone` が公開している `TransitionZoneBridge` インターフェースを介して `async_zone` と連動します。transition 中に descendant の `ZoneWidget` が `Future` を throw すると、bridge は次のように動作します：

1. その Future を進行中の transition に登録する。
2. `AsyncZone` の fallback に切り替えるのではなく、直前にコミットされていた subtree を画面に残す。
3. tracked な Future が 1 つでも未解決の間は `isPending` を `true` にし、すべて解決したら `false` に戻す。

bridge の lookup は `TransitionBoundary` が `ZoneWidget` の上にあることだけを要件としており、`AsyncZone` の上に置くのは UX 上の慣習です（トリガーを `AsyncZone` の fallback の影響範囲の外に保ちたいため）。

### 非同期 action の自動 track

`action` 自体が `Future` を返した場合（典型的には `async` で宣言されたケース）、`startTransition` はその Future を自動で track します。これにより、suspend する `ZoneWidget` が無くても `compute()` などの明示的な非同期処理の間ずっと `isPending` を true に保てます：

```dart
scope.startTransition(() async {
  final data = await api.fetchUser(id);
  final result = await compute(_expensiveTransform, data);
  setState(() => _data = result);
});
```

### `forceSameFrameRebuild`

デフォルトでは `isPending` は transition 開始の **次のフレーム** で true になります。次のフレームで boundary が再ビルドされ、suspend した Future が tracked セットに入り、post-frame コールバックで `isPending` が flip する流れです。この 1 フレームの遅延は安全側に倒した既定値で、視覚的にもほとんど気付かない程度です。

`forceSameFrameRebuild: true` を渡すと、boundary の再ビルド中に dirty な descendant を強制的に同期ビルドするようになります。同一フレーム内で suspend した Future が settle 前に tracked セットに入るため、`isPending` は transition を開始したまさにそのフレームで flip します：

```dart
TransitionBoundary(
  forceSameFrameRebuild: true,
  child: ...,
)
```

1 フレームの遅延が視覚的に目立つときだけ有効化してください。同期で subtree を walk する分、transition 開始ごとの処理コストは増えます。

## 高度な使用方法

### 挙動のメモ

- **`isPending` は実際に待つべき処理があるときだけ true になる。** descendant の `ZoneWidget` が何も throw せず `action` も `Future` を返さない no-op transition は、1 フレームの flicker すら起こさず静かに終わります。
- **同じ箇所を連打した場合は自動 supersede される。** descendant の `ZoneWidget` が新しい Future で再ビルドされると、bridge は古い Future の追跡を解除して新しい Future を track し直します。`isPending` は最新の処理を反映するもので、重なっている呼び出しの和集合ではありません。Future 自体はキャンセルされません — *ライフサイクル* を参照。
- **非同期 action の Future は supersede されず merge される。** `action` が `Future` を返す場合、重なる `startTransition` 呼び出しはどれも track されたままになり、それぞれが解決するまで保持されます。進行中の非同期処理のキャンセルは呼び出し側の責任です。
- **`useDeferredValue` 相当はない。** Flutter のレンダラは同期的で、レンダリングの中断機能は存在しません。重い CPU 処理は `compute()` / `Isolate.run` にオフロードし、deferred-value 的な挙動は state とエフェクトの組み合わせで実装してください。

### 入れ子の `startTransition`

transition 進行中に呼ばれた `startTransition` は、外側の transition に取り込まれます。内側の action は同期的に実行され、そこから生まれた Future も既存の transition に track されます。内側に独立した transition state が新たに作られることはありません。

### 新規マウントでは fallback に切り替わる

suspend する element に過去にコミット済みのビルドが無い場合 — リトライ後に子に戻ったばかりの `ErrorBoundary`、新規挿入されたルート、新しくマウントされた `AsyncZone` の最初のビルドなど — 残しておくべき UI がそもそも存在しません。suspend した Future は通常の Suspense と同じく、囲みの `AsyncZone` の fallback に振り分けられます。

### ライフサイクル

- **pending な Future は unmount でキャンセルされない。** Dart の `Future` にはキャンセル機構がありません。boundary が unmount されると bridge は未解決の Future の追跡を止めますが、その下で走っている処理（HTTP リクエスト、ファイル I/O など）は止まりません。真にキャンセルしたい場合は `package:async` の `CancelableOperation` を使ってください。
- **hooks との組み合わせ。** transition の中で hooks（`useState` など）を使いたい場合は、hooks を使うウィジェットを `TransitionBoundary` でラップし、descendant 側で `TransitionZone.of(context)` から scope を取得してください。

## API リファレンス

### TransitionBoundary

| プロパティ              | 型       | 説明                                                                                          |
| ----------------------- | -------- | --------------------------------------------------------------------------------------------- |
| `child`                 | `Widget` | この transition scope の中に置くサブツリー。                                                  |
| `forceSameFrameRebuild` | `bool`   | `true` のとき、transition を開始したフレームと同じフレームで `isPending` を立てる。デフォルトは `false`。 |

### TransitionZone

囲みの scope を参照するための名前空間。インスタンス化はできません。

- `TransitionZone.of(context)` — 最寄りの `TransitionBoundary` から `TransitionZoneScope` を取得します。`context` を `isPending` の変化に追従させます。boundary が無い場合は `FlutterError` を throw します。
- `TransitionZone.maybeOf(context)` — `of` と同じですが、boundary が無い場合は `null` を返します。

### TransitionZoneScope

`TransitionZone.of` が返す scope。

- `bool get isPending` — 進行中の transition で track している Future が 1 つでも未解決の間は `true`。
- `void startTransition(FutureOr<void> Function() action)` — `action` を transition の中で同期的に実行します。状態更新は次のビルドで反映され、descendant の `ZoneWidget` が throw した Future や、`action` 自身が返した `Future` も自動で track されます。

## 関連パッケージ

- [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) — 宣言的な非同期処理とエラーバウンダリー（このパッケージが実装する `TransitionZoneBridge` / `TransitionZoneProvider` インターフェースを公開しています）
- [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary) — 宣言的なエラーハンドリング
- [hooks_async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/hooks_async_zone) — `async_zone` の `flutter_hooks` 統合

## ライセンス

このプロジェクトは BSD 3-Clause License の下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## インスピレーション

このパッケージは、新しい状態が suspend している間も直前の UI を画面に残す React の `useTransition` フックからインスパイアされています。
