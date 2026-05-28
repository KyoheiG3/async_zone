# hooks_async_zone

**English** | [日本語](README.ja.md)

A Flutter package that provides [flutter_hooks](https://github.com/rrousselGit/flutter_hooks) integration for [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone).

## Overview

This package bridges Flutter hooks with `async_zone`. Use `HookZoneWidget` to write hooks alongside an `AsyncZone`, or `HookErrorZoneWidget` to combine them with an error boundary. The `useAsyncZone` hook exposes the surrounding `AsyncZoneScope`, and `HookZoneBuilder` offers a convenient inline form.

## Installation

```bash
flutter pub add hooks_async_zone
```

## Quick Start

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
    // Memoize the future so the same instance is reused across rebuilds.
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

// Wrap with AsyncZone
AsyncZone(
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)
```

## Why hooks_async_zone?

To use [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) with [flutter_hooks](https://github.com/rrousselGit/flutter_hooks), you need custom elements that mixin both `HookElement` and `ZoneElement`:

```dart
// Without hooks_async_zone:
abstract class ZoneHookWidget extends HookWidget {
  const ZoneHookWidget({super.key});
  @override
  ZoneHookElement createElement() => ZoneHookElement(this);
}

class ZoneHookElement extends StatelessElement with HookElement, ZoneElement {
  ZoneHookElement(super.widget);
}
```

With `hooks_async_zone`, simply use `HookZoneWidget`.

## API Reference

### HookZoneWidget / StatefulHookZoneWidget

Base classes for widgets with hooks and zone functionality.

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

Base classes with hooks, zones, and error boundaries. Must implement `getDerivedStateFromError` and handle error state in `build`:

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

Convenience widget for inline usage:

```dart
HookZoneBuilder(
  builder: (context) {
    final counter = useState(0);
    return Text('Counter: ${counter.value}');
  },
)
```

### SliverHookZoneWidget / SliverStatefulHookZoneWidget / SliverHookZoneBuilder

Sliver-shaped counterparts of the above. Use these when the suspending hook-using widget must live directly inside a `CustomScrollView`:

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

The surrounding `AsyncZone` stays a regular box widget.

### useAsyncZone

Returns the [`AsyncZoneScope`](../async_zone) of the surrounding `AsyncZone`. The hook itself only locates the scope — the actual async consumption happens via `zone.use(future)`, which behaves like React's `use()` and **may be called inside conditionals, loops, or after early returns**:

```dart
final zone = useAsyncZone();
final future = useMemoized(() => fetchData());

if (!showDetails) return const SizedBox.shrink();

final data = zone.use(future);
```

The cache is keyed on the Future instance, so memoize the future (e.g. with `useMemoized`) instead of calling `fetchData()` directly inside `build()` — otherwise every rebuild produces a new Future and the cache never matches.

Equivalent to:

```dart
final zone = AsyncZone.of(context);
final future = useMemoized(() => fetchData());
final data = zone.use(future);
```

## Related Packages

- [async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_zone) - Declarative async operations and error boundaries
- [async_error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/async_error_boundary) - Declarative error handling
- [flutter_hooks](https://github.com/rrousselGit/flutter_hooks) - React hooks for Flutter

## License

BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
