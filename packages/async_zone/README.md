# async_zone

**English** | [日本語](README.ja.md)

A Flutter package that provides declarative async operations and error boundaries, inspired by React's Suspense and Error Boundary.

## Features

- 🔄 **AsyncZone**: Declarative async operations with automatic fallback UI
- 🛡️ **ErrorZoneWidget**: Custom error handling with React-like lifecycle methods
- 🎯 **ZoneWidget**: Seamless integration of async and error handling
- 🚀 **Simple API**: Minimal boilerplate with powerful capabilities
- ⚡ **Performance**: Efficient caching and rebuild optimization

## Installation

```bash
flutter pub add async_zone
```

Or add it manually to your `pubspec.yaml`:

```yaml
dependencies:
  async_zone:
```

Then run:

```bash
flutter pub get
```

## Quick Start

### AsyncZone - Handle Async Operations (inspired by React Suspense)

Wrap your widget tree with `AsyncZone` and `use()` a future inside any
`ZoneWidget` descendant. While the future is pending the zone shows
`fallback` instead of `child`.

#### Inline with `ZoneBuilder` (no class needed)

For one-off cases, hold the future somewhere stable and consume it inside a
`ZoneBuilder`:

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

#### Reusable widget with `StatefulZoneWidget`

When you need a widget that owns its future, extend `StatefulZoneWidget` and
hold the instance in a `late final` field so the same `Future` is reused
across rebuilds:

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

### ErrorZoneWidget - Custom Error Handling (inspired by React Error Boundary)

Create custom error handling with React-like lifecycle methods:

```dart
import 'package:async_zone/async_zone.dart';

class MyErrorZone extends ErrorZoneWidget<({Object? error})> {
  const MyErrorZone({super.key, required this.child});

  final Widget child;

  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    // Log error to your error reporting service
    print('Error caught: $error');
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
          Text('Error: ${state.error}'),
          ElevatedButton(
            onPressed: resetErrorBoundary,
            child: Text('Retry'),
          ),
        ],
      );
    }
    return child;
  }
}
```

> **Note:** For a simpler error boundary implementation, check out the [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary) package.

## Core Concepts

### ZoneWidget and ZoneElement - Important Requirements

**⚠️ Critical:** Suspending and error catching only work inside the `build()`
of a widget whose `Element` mixes in `ZoneElement`. The exported base classes
(`ZoneWidget` / `StatefulZoneWidget` / `ZoneBuilder`) take care of this for
you. Two non-obvious traps to avoid:

```dart
// ❌ Plain StatelessWidget — its Element does not mix in ZoneElement,
//    so the thrown Future leaks out as an opaque build error.
class Wrong extends StatelessWidget {
  @override
  Widget build(BuildContext context) => throw fetchData();
}

// ❌ Throwing outside build() (e.g. inside an event handler) is never
//    caught — only build-time throws are observable to the zone.
class WrongHandler extends ZoneWidget {
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: () => throw Exception('not caught'),
        child: const Text('Click'),
      );
}
```

If you need to combine `ZoneElement` with another `Element` mixin (e.g.
`HookElement` from `flutter_hooks`), use the
[hooks_async_zone](https://github.com/KyoheiG3/async_zone/tree/main/packages/hooks_async_zone) package instead
of building the boilerplate yourself. For other libraries, define a custom
`Element` that mixes in `ZoneElement` — that is the only requirement.

### AsyncZone

`AsyncZone` manages async operations and displays fallback UI while they're pending. This is inspired by React's Suspense.

#### Recommended - Caching with use()

`use()` keys its cache on the **identity of the Future instance**: the first call schedules the future and throws it; subsequent rebuilds with the same instance return the cached value. This means you must hold the future somewhere stable (a `late final` field, a parent widget's state, `useMemoized`, etc.). Calling `fetchData()` directly inside `build()` creates a new `Future` on every rebuild, the cache never matches, and the widget falls into an infinite rebuild loop.

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

#### Common pitfalls

The cache key is the **identity of the `Future` object** itself. Any
expression that produces a new `Future` on each rebuild defeats the cache and
triggers an infinite rebuild loop.

**❌ Calling the fetcher directly inside `build()`**

```dart
@override
Widget build(BuildContext context) {
  // New Future on every rebuild → never hits cache
  final data = AsyncZone.of(context).use(fetchData());
  return Text(data);
}
```

**❌ Chaining `.then()` / `.catchError()` / `.timeout()` etc. inside `build()`**

`Future.then()` (and friends) return a *new* `Future` on every call, so
chaining inside `build()` has the same effect as calling the fetcher inline:

```dart
late final Future<User> _userFuture = fetchUser();

@override
Widget build(BuildContext context) {
  // _userFuture.then(...) is a brand-new Future each build
  final name = AsyncZone.of(context).use(_userFuture.then((u) => u.name));
  return Text(name);
}
```

✅ Cache the chained future itself:

```dart
late final Future<User> _userFuture = fetchUser();
late final Future<String> _nameFuture = _userFuture.then((u) => u.name);
```

**Rule of thumb:** if you can't point to a specific `late final` field,
`State` field, hook ref (`useMemoized`, `useState`), or external store that
holds the **exact** `Future` instance you pass to `use()`, the cache will
miss. The same logic rules out inline `(() async { ... })()` invocations and
any other expression that constructs a fresh `Future` per build. When in
doubt, save the future to a named variable first and pass that variable in.

#### Advanced - Direct throw

You can also directly throw futures, but this requires careful management to avoid infinite rebuild loops. The future must be stored in a field to maintain the same instance:

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

    // Must store and reuse the exact same future instance
    _future.then((data) {
      if (mounted) setState(() => _data = data);
    });
    throw _future;
  }
}
```

**Direct `throw` vs `use()`:**

- **`use()`** (Recommended): Identity-based caching of the Future, simpler to use as long as the same instance is passed across rebuilds
- **Direct `throw`**: More control but requires careful state management

## Advanced Usage

### Nested `AsyncZone`s

`AsyncZone` is composable: each one only sees suspends from `ZoneWidget`s
that resolve `AsyncZone.of(context)` to *this* zone — i.e. descendants below
the inner zone's `InheritedWidget`. The outer zone shows its fallback only
when something between the two zones (or outside the inner one) suspends.

```dart
AsyncZone(                          // outer
  fallback: const Text('outer…'),
  child: Column(children: [
    SuspendsAgainstOuter(),          // suspends here → outer fallback
    AsyncZone(                       // inner
      fallback: const Text('inner…'),
      child: SuspendsAgainstInner(), // suspends here → inner fallback only
    ),
  ]),
)
```

The cache (`use()` results) and the pending-task set are scoped per
`AsyncZone`, so two zones never share state. To suspend the inner subtree
*against the outer* zone, lift the suspending widget above the inner
`AsyncZone`.

### Lifecycle and unmount behavior

A few things worth knowing once an app actually runs:

- **Pending futures are not cancelled on unmount.** Dart's `Future` has no
  cancel primitive. The element's `mounted` guard means a late completion
  is silently ignored — `markNeedsBuild()` never fires on a disposed
  element — but the underlying work (HTTP request, file I/O, etc.) keeps
  running. Use `CancelableOperation` from `package:async` if you need true
  cancellation.
- **The cache is GC-based, not lifecycle-based.** `AsyncZoneProviderElement`
  holds completed values in an `Expando` keyed on the `Future` instance.
  Once the future is no longer referenced, the cache entry becomes eligible
  for GC automatically — there is no manual eviction.
- **Hot reload preserves `late final` fields.** A `late final _future =
  fetchData()` set during a previous run is not re-run on hot reload, so
  edits to the fetcher body do not take effect until you hot restart.

### Concurrent vs Sequential Builds

Control whether sibling `ZoneWidget`s in this zone may build concurrently
while another future is pending:

```dart
AsyncZone(
  allowConcurrentBuilds: false, // Default is true
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)
```

- `true` (default): each `ZoneWidget` evaluates independently and may suspend
  on its own future. All thrown futures are awaited concurrently and the
  fallback is shown until every one of them resolves.
- `false`: only one `ZoneWidget` is allowed to suspend at a time. As soon as
  one future is thrown, sibling `ZoneWidget`s render an empty placeholder
  for the rest of that build pass — their futures are not started until the
  in-flight one completes (sequential loading). Plain `StatelessWidget` /
  `StatefulWidget` descendants are unaffected; this flag only gates
  `ZoneElement`-mixed elements.

> **Note:** Frozen futures (`use(future, freeze: true)`) are exempt from
> this gate. They are not registered with the zone as tracked tasks, so
> other `ZoneWidget`s keep building normally even when
> `allowConcurrentBuilds: false`.

### Freeze: Keep Previous UI During Reload (Optional)

`use()` accepts an optional `freeze` flag. When `true`, the surrounding `AsyncZone` keeps the previously rendered subtree on screen while the new future is pending, instead of swapping to the fallback. This gives a "transition-style" reload (no fallback flash on rapid swaps).

> **Note:** This is provided for completeness as a Suspense-style primitive, and **not generally recommended for production**. In real apps, caching libraries such as [Riverpod](https://github.com/rrousselGit/riverpod) or [fquery](https://github.com/41y08h/fquery) usually offer a more flexible solution (stale-while-revalidate, explicit `isFetching` flags, etc.). Reach for `freeze` only if you intentionally want to stay inside the Suspense pattern.

#### Basic usage

```dart
final data = AsyncZone.of(context).use(future, freeze: true);
```

#### Initial-mount caveat

Passing `freeze: true` on the **very first** render means there is no previous subtree to keep, so the suspending widget renders `Empty()` and no fallback appears. You almost always want `freeze: false` for the first render and `true` for subsequent reloads.

If you do want to use this feature, a small helper hook captures the idiom:

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

// Usage inside a HookZoneWidget / HookErrorZoneWidget:
final use = useFreezing();
final user = use(userFuture);
final post = use(postFuture); // works for any T
```

The `built` ref starts `false`, so the first `use()` call falls through to the normal fallback path. After that call returns successfully, `built` flips to `true` and every subsequent call freezes the previous UI instead of showing the fallback.

#### Caveats

- **No `isPending` indicator.** The freeze state is only confirmed *after* the future is thrown, so any widget upstream that would react to it has already built with the old value. Cross-fade or opacity dimming during freeze has to be driven by your own state (e.g. a `ChangeNotifier`).
- **Freeze is local to the suspending widget.** Only the calling `ZoneWidget`'s own subtree is kept on screen — sibling `ZoneWidget`s under the same `AsyncZone` continue to build normally, and updates from above (theme/locale changes, etc.) still propagate. A suspending widget cannot update its display until the future resolves, but it does not block the rest of the zone. As a corollary, frozen futures do not count against `allowConcurrentBuilds: false`: other `ZoneWidget`s remain free to build even while one is frozen.

### Inside `CustomScrollView`

When the suspending widget needs to return a sliver, use `SliverZoneWidget` / `SliverStatefulZoneWidget` / `SliverZoneBuilder`. The slot stays a valid sliver while suspended. The surrounding `AsyncZone` is still a regular box widget — wrap the `CustomScrollView` with it as usual.

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

### Custom Error Zones

#### Choosing between `ErrorBoundary` and `ErrorZoneWidget`

The companion [error_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/error_boundary)
package wraps `ErrorZoneWidget` into a single configurable widget
(`ErrorBoundary`). Reach for it unless you have a specific reason to drop
down to the lower-level API.

| You want…                                                              | Use                                |
| ---------------------------------------------------------------------- | ---------------------------------- |
| A `builder(context, error, reset)` fallback                            | `ErrorBoundary` (error_boundary)   |
| Auto-reset when external values change (`resetKeys`)                   | `ErrorBoundary` (error_boundary)   |
| `onError` / `onReset` callbacks without subclassing                    | `ErrorBoundary` (error_boundary)   |
| A custom state shape beyond `(error: …)` (e.g. retry counts, error category) | `ErrorZoneWidget<T>` |
| Mix the lifecycle into a non-`StatelessWidget` hierarchy               | `ErrorBoundaryMixin<T>` + custom `Element` |

#### Method 1: Extending ErrorZoneWidget

Create custom error handling by extending `ErrorZoneWidget`:

```dart
class MyCustomErrorZone extends ErrorZoneWidget<({Object? error})> {
  const MyCustomErrorZone({super.key, required this.child});

  final Widget child;

  @override
  void componentDidCatch(Object error, StackTrace stackTrace) {
    // Custom error handling logic
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

#### Method 2: Using ErrorBoundaryMixin and ErrorZoneElement Directly

If you need more control, mixin `ErrorBoundaryMixin` and create a custom element with `ErrorZoneElement`:

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

This gives you full control over the element lifecycle.

### Nested Error Zones

When `ErrorZoneWidget` (or any widget using `ErrorZoneElement`) is nested, errors thrown by an inner fallback escalate to the next outer error zone, mirroring React's error boundary semantics. This applies to:

- Errors thrown synchronously while the inner zone is rendering its fallback
- Errors thrown by `ZoneWidget` descendants of that fallback

```dart
MyOuterErrorZone( // handles what inner cannot
  child: MyInnerErrorZone(
    // when its build/fallback throws an unrecoverable error,
    // the outer zone catches it
    child: SomeWidget(),
  ),
)
```

This works at the `ErrorZoneElement` mixin level, so any widget that uses `ErrorZoneElement` participates automatically. If no outer error zone exists, the rethrow surfaces as an unhandled build error.

## Examples

Check out the [example](example/) directory for complete examples including:

- Basic async operations
- Custom error zones with ErrorZoneWidget
- Nested async zones
- Error recovery patterns
- Integration with state management

## API Reference

### AsyncZone

| Property              | Type     | Description                                          |
| --------------------- | -------- | ---------------------------------------------------- |
| `fallback`            | `Widget` | Widget to display while async operations are pending |
| `child`               | `Widget` | Main content widget                                  |
| `allowConcurrentBuilds` | `bool` | Whether sibling `ZoneWidget`s may suspend concurrently (default: `true`) |

**Methods:**

- `AsyncZone.of(context)` - Returns `AsyncZoneScope` for consuming futures via `use()`. The `use()` method accepts an optional `freeze: true` flag — see [Freeze](#freeze-keep-previous-ui-during-reload-optional).

### ErrorZoneWidget / StatefulErrorZoneWidget

Abstract base classes for widgets with custom error handling capabilities.

- Extend `ErrorZoneWidget` for stateless error zones
- Extend `StatefulErrorZoneWidget` for stateful error zones
- Implement `getDerivedStateFromError` to derive error state
- Optionally override `componentDidCatch` for error logging/reporting
- Use `resetErrorBoundary()` and `showErrorBoundary()` methods for manual control

### ZoneWidget / StatefulZoneWidget

Abstract base classes for widgets with integrated async and error handling.

- Extend `ZoneWidget` for `StatelessWidget`
- Extend `StatefulZoneWidget` for `StatefulWidget`

### ZoneBuilder

A convenience widget that provides zone functionality through a builder pattern.

This widget is useful when you want to use zones without creating a custom widget class. It's similar to `Builder` but with zone support.

**Example:**

```dart
final future = fetchData(); // hold the same instance across rebuilds

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

Sliver-shaped counterparts of `ZoneWidget` / `StatefulZoneWidget` / `ZoneBuilder`. Use these when the suspending widget must live directly inside a `CustomScrollView`. The surrounding `AsyncZone` stays box-shaped — see [Inside `CustomScrollView`](#inside-customscrollview).

## Comparison with Other Solutions

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
      return Text('Error: ${snapshot.error}');
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

**Benefits:**

- Fallback UI is handled by the parent, not duplicated in every leaf
- Identity-based caching via `use()` — the future runs once per instance
- Cleaner separation of concerns
- Better composability

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Inspiration

This package is inspired by:

- React's Suspense for async operations
- React's Error Boundary for error handling
- Flutter's declarative UI principles
