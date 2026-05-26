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

Wrap your widget tree with `AsyncZone` and `use()` a future inside a
`ZoneWidget` descendant. While the future is pending the zone shows
`fallback` instead of `child`.

#### Stateless: extend `ZoneWidget`

`ZoneWidget` is the `StatelessWidget` counterpart. Hold the future somewhere
stable (here, injected as a property) so the same instance is passed across
rebuilds:

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

// usage
final greeting = Future.delayed(const Duration(seconds: 2), () => 'Hello!');

AsyncZone(
  fallback: const CircularProgressIndicator(),
  child: Greeting(future: greeting),
)
```

#### Stateful: extend `StatefulZoneWidget`

`StatefulZoneWidget` is the `StatefulWidget` counterpart. When the widget
owns its future, hold the instance in a `late final` field so the same
`Future` is reused across rebuilds:

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

#### Inline alternative: `ZoneBuilder`

For one-off cases where defining a class adds noise, `ZoneBuilder` consumes
the future inline. The same rule applies — the future must be held somewhere
stable, not constructed inside the builder:

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

> **Note:** For React `useTransition`-style transitions that keep the previous subtree visible while a new state suspends, check out the separate [transition_boundary](https://github.com/KyoheiG3/async_zone/tree/main/packages/transition_boundary) package. `async_zone` only exposes the bridge interface (`TransitionZoneBridge` / `TransitionZoneProvider`) that lets external coordinators plug in.

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

> **Note:** `ErrorBoundary` and `ErrorZoneWidget` are box-shaped. Place them outside the `CustomScrollView` (or above the sliver subtree); they cannot be nested directly inside the sliver list because their fallback/escalation paths render box widgets.

For custom sliver-shaped elements (e.g. combining hooks or third-party packages with `ZoneElement`), mix in `SliverZoneElementMixin` alongside `ZoneElement`:

```dart
class MyCustomSliverElement extends StatelessElement
    with SomeMixin, ZoneElement, SliverZoneElementMixin {
  MyCustomSliverElement(super.widget);
}
```

The mixin overrides the suspended placeholder to remain a valid sliver.

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

| Property    | Type                | Description                                                                                                            |
| ----------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `fallback`  | `Widget`            | Widget to display while async operations are pending                                                                   |
| `child`     | `Widget`            | Main content widget                                                                                                    |
| `alignment` | `AlignmentGeometry` | Alignment for the internal `Stack` overlaying `fallback` on `child`. Defaults to `Alignment.center`.                   |
| `fit`       | `StackFit`          | Sizing strategy for the internal `Stack` — defaults to `StackFit.passthrough` so incoming constraints are forwarded.   |

**Methods:**

- `AsyncZone.of(context)` - Returns `AsyncZoneScope` for consuming futures via `use()`. Throws a `FlutterError` if no `AsyncZone` ancestor is found, or if the calling context's `Element` does not mix in `ZoneElement`.

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
