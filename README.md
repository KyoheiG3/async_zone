# async_zone

**English** | [日本語](README.ja.md)

A Flutter package that provides declarative async operations and error boundaries, inspired by React's Suspense and Error Boundaries.

## Features

- 🔄 **AsyncZone**: Declarative async operations with automatic fallback UI
- 🛡️ **ErrorBoundary**: Catch and handle errors in widget trees
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

class MyDataWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    // Using use() for caching
    final data = AsyncZone.of(context).use(fetchData());
    return Text(data);
  }

  Future<String> fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
  }
}
```

### ErrorBoundary - Handle Errors Gracefully (inspired by React Error Boundaries)

Catch errors in your widget tree and display fallback UI:

```dart
import 'package:async_zone/async_zone.dart';

ErrorBoundary(
  builder: (context, error, reset) => Column(
    children: [
      Text('Error: $error'),
      ElevatedButton(
        onPressed: reset,
        child: Text('Retry'),
      ),
    ],
  ),
  onError: (error, stackTrace) {
    // Log error to your error reporting service
    print('Error caught: $error');
  },
  child: MyWidget(),
)
```

## Core Concepts

### ZoneWidget and ZoneElement - Important Requirements

**⚠️ Critical:** Your widget must use `ZoneElement` to handle futures and errors thrown in `build()`.

**Requirements:**

- Extend `ZoneWidget` or `StatefulZoneWidget`
- Throw futures/errors inside `build()` method only
- Regular `StatelessWidget`/`StatefulWidget` won't work

**Correct:**

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw fetchData();  // ✅ Throws future in build()
    // Or: final data = AsyncZone.of(context).use(fetchData());
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

    // ✅ Works with both Hooks and AsyncZone!
    final data = AsyncZone.of(context).use(fetchData());

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

The recommended way is to use `use()` which handles caching automatically:

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(fetchData());
    return Text(data);
  }

  Future<String> fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    return 'Hello, AsyncZone!';
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

- **`use()`** (Recommended): Automatic caching and simpler to use
- **Direct `throw`**: More control but requires careful state management

### ErrorBoundary

`ErrorBoundary` catches errors from child widgets and displays fallback UI instead of crashing. This is inspired by React's Error Boundaries.

**Important:** Only errors thrown from the `build()` method of `ZoneWidget` or `StatefulZoneWidget` will be caught.

**Key Features:**

- Declarative error handling
- Reset capability to recover from errors
- Error callbacks for logging/reporting
- Programmatic error triggering via `showBoundary`

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

### Accessing Error Boundary from Descendants

You can manually trigger error boundaries from anywhere in the tree:

```dart
final provider = ErrorBoundary.of(context);

// Manually show an error
provider.showBoundary(Exception('Something went wrong'));

// Reset the error boundary
provider.resetBoundary();
```

### Custom Error Zones

#### Method 1: Extending ErrorZone

Create custom error handling by extending `ErrorZone`:

```dart
class MyCustomErrorZone extends ErrorZone<({Object? error})> {
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

#### Method 2: Using ErrorZoneWidget and ErrorZoneElement Directly

If you need more control, mixin `ErrorZoneWidget` and create a custom element with `ErrorZoneElement`:

```dart
class MyCustomWidget extends StatelessWidget with ErrorZoneWidget<({Object? error})> {
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

## Examples

Check out the [example](example/) directory for complete examples including:

- Basic async operations
- Error boundary usage
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

### ErrorBoundary

| Property  | Type                   | Description                               |
| --------- | ---------------------- | ----------------------------------------- |
| `builder` | `ErrorFallbackBuilder` | Builder for fallback UI when error occurs |
| `child`   | `Widget`               | Child widget to wrap                      |
| `onError` | `Function?`            | Callback when error is caught             |
| `onReset` | `Function?`            | Callback when boundary is reset           |

**Methods:**

- `ErrorBoundary.of(context)` - Returns `ErrorBoundaryProvider` for manual control

### ZoneWidget / StatefulZoneWidget

Abstract base classes for widgets with integrated async and error handling.

- Extend `ZoneWidget` for stateless widgets
- Extend `StatefulZoneWidget` for stateful widgets

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

class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    final data = AsyncZone.of(context).use(fetchData());
    return Text(data);
  }
}
```

**Benefits:**

- Less boilerplate
- Automatic caching
- Cleaner separation of concerns
- Better composability

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Inspiration

This package is inspired by:

- React's Suspense for async operations
- React's Error Boundaries for error handling
- Flutter's declarative UI principles
