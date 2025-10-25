# error_boundary

**English** | [日本語](README.ja.md)

A Flutter package that provides declarative error handling for widget trees, inspired by React's Error Boundary.

## Features

- 🛡️ **ErrorBoundary**: Catch and handle errors in widget trees
- 🎯 **ZoneWidget Integration**: Seamless error handling with ZoneWidget
- 🔄 **Reset Capability**: Recover from errors with built-in reset functionality
- 📊 **Error Callbacks**: Log and report errors with onError callback
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

### ZoneWidget and ZoneElement - Important Requirements

**⚠️ Critical:** Your widget must use `ZoneElement` to handle errors thrown in `build()`.

**Requirements:**

- Extend `ZoneWidget` or `StatefulZoneWidget`
- Throw errors inside `build()` method only
- Regular `StatelessWidget`/`StatefulWidget` won't work

**Correct:**

```dart
class MyWidget extends ZoneWidget {
  @override
  Widget build(BuildContext context) {
    throw Exception('Error');  // ✅ Throws error in build()
  }
}
```

**Incorrect:**

```dart
class MyWidget extends StatelessWidget {  // ❌ Not a ZoneWidget
  @override
  Widget build(BuildContext context) {
    throw Exception('Error');  // ❌ Won't be caught
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

### ErrorBoundary

`ErrorBoundary` catches errors from child widgets and displays fallback UI instead of crashing. This is inspired by React's Error Boundary.

**Important:** Only errors thrown from the `build()` method of `ZoneWidget` or `StatefulZoneWidget` will be caught.

**Key Features:**

- Declarative error handling
- Reset capability to recover from errors
- Error callbacks for logging/reporting
- Programmatic error triggering via `showBoundary`

## Advanced Usage

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

| Property  | Type                   | Description                               |
| --------- | ---------------------- | ----------------------------------------- |
| `builder` | `ErrorFallbackBuilder` | Builder for fallback UI when error occurs |
| `child`   | `Widget`               | Child widget to wrap                      |
| `onError` | `Function?`            | Callback when error is caught             |
| `onReset` | `Function?`            | Callback when boundary is reset           |

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
