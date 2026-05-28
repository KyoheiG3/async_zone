# async_zone_sample

A Flutter sample app that demonstrates `async_zone`, `hooks_async_zone`, `async_error_boundary`, and `transition_boundary` working together — a React-style Suspense + `use()` + `useTransition` pattern, without any external state-management library.

## What it shows

A "user card" that fetches `https://dummyjson.com/users/{id}` and renders one user at a time. **Prev** / **Next** swap the id, and **Force error** triggers a failure that is caught by the boundary.

- While a fetch is in flight on first mount, `AsyncZone` shows a `CircularProgressIndicator` fallback.
- On subsequent fetches, `TransitionBoundary` keeps the previous user visible (dimmed via `isPending`) instead of falling back to the spinner.
- When the fetch fails, `ErrorBoundary` swaps in an error card with a **Retry** button.

## Pieces involved

- **`AsyncZone(fallback: ...)`** — Suspense-style boundary. Any `Future` thrown during build of a descendant is awaited, and `fallback` is shown until it resolves.
- **`HookZoneWidget` + `useAsyncZone().use(future)`** ([lib/main.dart](lib/main.dart)) — `use()` returns the resolved value when available, otherwise throws the `Future` for the enclosing `AsyncZone` to catch.
- **`ErrorBoundary`** — catches errors thrown during build, including errors that propagate out of `AsyncZone` when a suspended `Future` rejects, and renders `builder(context, error, reset)`. `onReset` re-issues the fetch so **Retry** works.
- **`TransitionBoundary` + `TransitionZone.of(context).startTransition(...)`** — wraps the state updates that swap `userFuture`. While the new future is pending, `isPending` is `true` and the previous result stays mounted, so the UI doesn't flash the fallback on every navigation.

## Run

```sh
flutter pub get
flutter run
```
