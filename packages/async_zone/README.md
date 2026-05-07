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

Wrap your widget tree with `AsyncZone` and throw futures to display fallback UI automatically:

```dart
import 'package:async_zone/async_zone.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AsyncZone(
      fallback: CircularProgressIndicator(),
      child: MyDataWidget(),
    );
  }
}

class MyDataWidget extends StatefulZoneWidget {
  const MyDataWidget({super.key});

  @override
  State<MyDataWidget> createState() => _MyDataWidgetState();
}

class _MyDataWidgetState extends State<MyDataWidget> {
  // Hold the future in a field so the same instance is reused across rebuilds.
  late final Future<String> _future = _fetchData();

  Future<String> _fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }

  @override
  Widget build(BuildContext context) {
    // Using use() for caching
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

> **Note:** For a simpler error boundary implementation, check out the [error_boundary](https://pub.dev/packages/error_boundary) package.

## Core Concepts

### ZoneWidget and ZoneElement - Important Requirements

**⚠️ Critical:** Your widget must use `ZoneElement` to handle futures and errors thrown in `build()`.

**Requirements:**

- Extend `ZoneWidget` or `StatefulZoneWidget`
- Throw futures/errors inside `build()` method only
- Regular `StatelessWidget`/`StatefulWidget` won't work

**Correct:**

```dart
class MyWidget extends StatefulZoneWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final _future = fetchData();

  @override
  Widget build(BuildContext context) {
    throw _future;  // ✅ Throws future in build()
    // Or: final data = AsyncZone.of(context).use(_future);
  }
}
```

**Incorrect:**

```dart
class MyWidget extends StatelessWidget {  // ❌ Not a ZoneWidget
  @override
  Widget build(BuildContext context) {
    throw fetchData();  // ❌ Won't be caught
  }
}

class MyButton extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => throw Exception('Error'),  // ❌ Outside build()
      child: Text('Click'),
    );
  }
}
```

#### Using ZoneElement with Other Widget Types

You don't have to extend `ZoneWidget` or `StatefulZoneWidget` - you can use `ZoneElement` with **any widget type** as long as it creates an element that mixins with `ZoneElement`. This allows you to combine async_zone functionality with other libraries like `flutter_hooks`:

```dart
// Custom base class combining HookWidget with ZoneElement
abstract class ZoneHookWidget extends HookWidget {
  const ZoneHookWidget({super.key});

  @override
  ZoneHookElement createElement() => ZoneHookElement(this);
}

// Custom element combining HookElement and ZoneElement
class ZoneHookElement extends StatelessElement with HookElement, ZoneElement {
  ZoneHookElement(super.widget);
}

// Now you can use it like ZoneWidget
class MyWidget extends ZoneHookWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = useState(0);
    // Memoize the future so the same instance is reused across rebuilds.
    final future = useMemoized(() => fetchData());

    // ✅ Works with both Hooks and AsyncZone!
    final data = AsyncZone.of(context).use(future);

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
}
```

**Key points:**

- The essential requirement is that your widget's element must mixin with `ZoneElement`
- You can combine `ZoneElement` with `HookElement`, or any other custom element
- This makes async_zone compatible with various Flutter libraries and patterns

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

### Parallel vs Sequential Builds

Control whether child widgets can build while async operations are pending:

```dart
AsyncZone(
  allowParallelBuilds: false, // Default is true
  fallback: CircularProgressIndicator(),
  child: MyWidget(),
)
```

- `true` (default): Child widgets continue building even with pending operations
- `false`: All child builds blocked while any operation is pending

### Custom Error Zones

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
| `allowParallelBuilds` | `bool`   | Whether to allow parallel builds (default: `true`)   |

**Methods:**

- `AsyncZone.of(context)` - Returns `AsyncZoneScope` for consuming futures

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
