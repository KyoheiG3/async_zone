# hooks_async_zone

[English](README.md) | **日本語**

[async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) に [flutter_hooks](https://github.com/rrousselGit/flutter_hooks) の統合を提供する Flutter パッケージです。

## 概要

このパッケージは、Flutter hooks と `async_zone` をつなぐためのものです。`HookZoneWidget` を使えば `AsyncZone` と一緒に hooks を書け、`HookErrorZoneWidget` ならエラーバウンダリと組み合わせられます。周囲の `AsyncZoneScope` は `useAsyncZone` hook で取得でき、もっと手軽に書きたいときは `HookZoneBuilder` でインラインに記述できます。

## インストール

```bash
flutter pub add hooks_async_zone
```

## クイックスタート

```dart
import 'package:hooks_async_zone/hooks_async_zone.dart';
import 'package:async_zone/async_zone.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class MyWidget extends HookZoneWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = useState(0);
    final zone = useAsyncZone();
    // future をメモ化してリビルド間で同じインスタンスを再利用する
    final future = useMemoized(() => fetchData());
    final data = zone.use(future);

    return Column(
      children: [
        Text('Counter: ${counter.value}'),
        Text('Data: $data'),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }

  Future<String> fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello!';
  }
}

// AsyncZone でラップ
AsyncZone(
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)
```

## なぜ hooks_async_zone が必要？

[async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) を [flutter_hooks](https://github.com/rrousselGit/flutter_hooks) と一緒に使うには、`HookElement` と `ZoneElement` の両方を mixin したカスタム element が必要です：

```dart
// hooks_async_zone を使わない場合:
abstract class ZoneHookWidget extends HookWidget {
  const ZoneHookWidget({super.key});
  @override
  ZoneHookElement createElement() => ZoneHookElement(this);
}

class ZoneHookElement extends StatelessElement with HookElement, ZoneElement {
  ZoneHookElement(super.widget);
}
```

`hooks_async_zone` を使えば、`HookZoneWidget` を使うだけです。

## API リファレンス

### HookZoneWidget / StatefulHookZoneWidget

hooks とゾーン機能を持つウィジェットの基底クラス。

```dart
class MyWidget extends HookZoneWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final state = useState(0);
    final future = useMemoized(() => fetchData());
    final data = useAsyncZone().use(future);
    return Text('$data');
  }
}
```

### HookErrorZoneWidget / StatefulHookErrorZoneWidget

hooks、ゾーン、エラーバウンダリを持つ基底クラス。`getDerivedStateFromError` を実装し、`build` でエラー状態を処理する必要があります：

```dart
class MyWidget extends HookErrorZoneWidget<({Object? error})> {
  MyWidget({super.key, required this.child});

  final Widget child;

  @override
  ({Object? error}) getDerivedStateFromError(Object? error) => (error: error);

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Text('Error: ${state.error}');
    }
    return child;
  }
}
```

### HookZoneBuilder

インライン使用のための便利なウィジェット：

```dart
HookZoneBuilder(
  builder: (context) {
    final counter = useState(0);
    return Text('Counter: ${counter.value}');
  },
)
```

### SliverHookZoneWidget / SliverStatefulHookZoneWidget / SliverHookZoneBuilder

上記の sliver 版。suspend する hooks を使う widget を `CustomScrollView` の直下に置く必要がある場合に使用：

```dart
AsyncZone(
  fallback: const CircularProgressIndicator(),
  child: CustomScrollView(
    slivers: [
      SliverHookZoneBuilder(
        builder: (context) {
          final future = useMemoized(fetchItems);
          final items = useAsyncZone().use(future);
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

境界の `AsyncZone` 自体は box widget のままです。

### useAsyncZone

周囲の `AsyncZone` の [`AsyncZoneScope`](../async_zone) を返す hook です。hook 自体はスコープを取得するだけで、実際の非同期消費は `zone.use(future)` で行います。`zone.use` は React の `use()` と同様に **条件分岐・ループ・早期リターンの後でも呼び出し可能** です：

```dart
final zone = useAsyncZone();
final future = useMemoized(() => fetchData());

if (!showDetails) return const SizedBox.shrink();

final data = zone.use(future);
```

キャッシュは Future インスタンスをキーにするため、`build()` 内で直接 `fetchData()` を呼ぶのではなく `useMemoized` などで future をメモ化してください — そうしないとリビルドのたびに新しい Future が生成され、キャッシュは一度もヒットしません。

次と同等です：

```dart
final zone = AsyncZone.of(context);
final future = useMemoized(() => fetchData());
final data = zone.use(future);
```

## 関連パッケージ

- [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) - 宣言的な非同期操作とエラーバウンダリ
- [async_error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_error_boundary) - 宣言的なエラーハンドリング
- [flutter_hooks](https://github.com/rrousselGit/flutter_hooks) - Flutter 用の React hooks

## ライセンス

BSD 3-Clause License - 詳細は [LICENSE](LICENSE) ファイルを参照してください。
