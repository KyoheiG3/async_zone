# error_boundary

**English** | [日本語](README.ja.md)

A Flutter package that provides declarative error handling for widget trees, inspired by React's Error Boundary.

## Features

- 🛡️ **ErrorBoundary**: Catch and handle errors in widget trees
- 🎯 **ZoneWidget Integration**: Seamless error handling with ZoneWidget
- 🔄 **Reset Capability**: Recover from errors with built-in reset functionality
- 📊 **Error Callbacks**: Log and report errors with onError callback
- 🔑 **Reset Keys**: Automatically reset when external values change
- 🚀 **Simple API**: Minimal boilerplate with powerful capabilities

## Installation

```bash
flutter pub add error_boundary
```

Or add it manually to your `pubspec.yaml`:

```yaml
dependencies:
  error_boundary:
```

Then run:

```bash
flutter pub get
```

## Quick Start

### ErrorBoundary - Handle Errors Gracefully

Catch errors in your widget tree and display fallback UI:

```dart
import 'package:error_boundary/error_boundary.dart';

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

### ErrorBoundary

`ErrorBoundary` catches errors from child widgets and displays fallback UI
instead of crashing, mirroring React's Error Boundary.

**Important — automatic catching only fires for `build()` throws inside a
widget whose `Element` mixes in `ZoneElement`** — typically `ZoneWidget`,
`StatefulZoneWidget`, or one of `hooks_async_zone`'s base classes. Errors
from a plain `StatelessWidget` / `StatefulWidget`, or thrown outside
`build()` (event handlers, post-frame callbacks, `Timer` callbacks, etc.)
are **not** caught automatically. For those, call
`ErrorBoundary.of(context).showBoundary(error)` from any widget — manual
triggering does not require `ZoneElement`.

**Key features:**

- Declarative error handling
- Reset capability to recover from errors
- `onError` / `onReset` callbacks for logging and side effects
- `resetKeys` for auto-reset on external value changes
- Programmatic triggering via `showBoundary`

## Advanced Usage

### Auto-reset with `resetKeys`

Pass `resetKeys` to automatically reset the boundary when external values change. Useful when a route argument, user id, or query key changes and the previous error is no longer relevant:

```dart
ErrorBoundary(
  resetKeys: [userId],
  builder: (context, error, reset) => ErrorView(
    error: error,
    onRetry: reset,
  ),
  child: UserProfile(userId: userId),
)
```

When any value in `resetKeys` differs from the previous render (compared by equality), the error state clears and `onReset` fires.

### Nested boundaries

When `ErrorBoundary` is nested, errors thrown by a fallback escalate to the next outer `ErrorBoundary`, mirroring React's error boundary semantics. This applies to:

- Errors thrown synchronously inside a fallback `builder`
- Errors thrown by a `ZoneWidget` rendered inside the fallback

```dart
ErrorBoundary( // outer - handles what inner cannot
  builder: (context, error, reset) => Text('Outer: $error'),
  child: ErrorBoundary( // inner
    builder: (context, error, reset) {
      if (error is AuthException) throw error; // delegate to outer
      return RetryView(error: error, onRetry: reset);
    },
    child: HomePage(),
  ),
)
```

If no outer boundary exists, the rethrow surfaces as an unhandled build error.

### Accessing Error Boundary from Descendants

You can manually trigger error boundaries from anywhere in the tree. Unlike automatic error catching which requires `ZoneWidget`, manual triggering works from **any widget** (including regular `StatelessWidget` or `StatefulWidget`):

```dart
// Works from any widget - no need to extend ZoneWidget
class MyRegularWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final provider = ErrorBoundary.of(context);

        // Manually show an error
        provider.showBoundary(Exception('Something went wrong'));
      },
      child: Text('Trigger Error'),
    );
  }
}

// Reset error boundary
final provider = ErrorBoundary.of(context);
provider.resetBoundary();
```

## API Reference

### ErrorBoundary

| Property    | Type                   | Description                                  |
| ----------- | ---------------------- | -------------------------------------------- |
| `builder`   | `ErrorFallbackBuilder` | Builder for fallback UI when error occurs    |
| `child`     | `Widget`               | Child widget to wrap                         |
| `onError`   | `Function?`            | Callback when error is caught                |
| `onReset`   | `Function?`            | Callback when boundary is reset              |
| `resetKeys` | `List<Object?>?`       | Auto-reset when any of these values change   |

**Methods:**

- `ErrorBoundary.of(context)` - Returns `ErrorBoundaryProvider` for manual control

### ZoneWidget / StatefulZoneWidget

Abstract base classes for widgets with integrated error handling.

- Extend `ZoneWidget` for stateless widgets
- Extend `StatefulZoneWidget` for stateful widgets

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Inspiration

This package is inspired by:

- React's Error Boundary for error handling
- Flutter's declarative UI principles
