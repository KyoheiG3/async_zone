# hooks_async_zone

**English** | [日本語](README.ja.md)

A Flutter package that provides [flutter_hooks](https://pub.dev/packages/flutter_hooks) integration for [async_zone](https://pub.dev/packages/async_zone).

## Features

- 🎣 **HookZoneWidget**: Use Flutter hooks with AsyncZone
- 🛡️ **HookErrorZoneWidget**: Combine hooks with error boundaries
- 🔄 **useAsyncZone**: Hook for consuming async operations
- 🚀 **HookZoneBuilder**: Convenience widget for inline usage

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
    final data = useAsyncZone(fetchData());

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

To use [async_zone](https://pub.dev/packages/async_zone) with [flutter_hooks](https://pub.dev/packages/flutter_hooks), you need custom elements that mixin both `HookElement` and `ZoneElement`:

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
    final data = useAsyncZone(fetchData());
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

### useAsyncZone

Hook for consuming async operations:

```dart
final data = useAsyncZone(fetchData());
```

Equivalent to:
```dart
final data = AsyncZone.of(context).use(fetchData());
```

## Related Packages

- [async_zone](https://pub.dev/packages/async_zone) - Declarative async operations and error boundaries
- [error_boundary](https://pub.dev/packages/error_boundary) - Declarative error handling
- [flutter_hooks](https://pub.dev/packages/flutter_hooks) - React hooks for Flutter

## License

BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
