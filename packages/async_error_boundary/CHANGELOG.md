## 0.1.0

Initial release.

### Features

- `ErrorBoundary` widget that catches errors thrown during the build of its descendants and renders a `builder(context, error, reset)` fallback, inspired by React's Error Boundary.
- `onError` callback for logging or reporting caught errors with the original stack trace.
- `onReset` callback that fires when the boundary is reset, receiving an optional argument forwarded from the fallback's reset function.
- `resetKeys` for automatic recovery: when any value in the list changes between rebuilds, the error state is cleared and `onReset` is invoked with `null`, mirroring `react-error-boundary` semantics.
- `ErrorBoundary.of(context)` returns an `ErrorBoundaryProvider` exposing `resetBoundary` and `showBoundary` for imperative control from descendant widgets.
- `ErrorBoundaryState` and `ErrorFallbackBuilder` typedefs for consumers that want to spell out the boundary's state shape or build their own fallbacks.

### Documentation

- Bilingual README (English / Japanese) with usage examples covering the builder fallback, `onError` / `onReset`, `resetKeys`, and nested boundaries.
