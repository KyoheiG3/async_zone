import 'package:async_zone/src/async/frozen_future.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrozenFuture', () {
    test('exposes the wrapped future via inner', () {
      final inner = Future<int>.value(42);
      final frozen = FrozenFuture<int>(inner);

      expect(frozen.inner, same(inner));
    });

    test('is assignable to Future<T>', () {
      final inner = Future<String>.value('value');
      // ignore: unused_local_variable
      final Future<String> asFuture = FrozenFuture<String>(inner);

      expect(asFuture, isA<Future<String>>());
    });

    test('then() delegates to inner.then', () async {
      final frozen = FrozenFuture<int>(Future<int>.value(2));

      final result = await frozen.then((value) => value * 3);

      expect(result, 6);
    });

    test('then() forwards onError to inner.then', () async {
      final frozen = FrozenFuture<int>(
        Future<int>.error('boom'),
      );

      final result = await frozen.then(
        (value) => value,
        onError: (Object error) => -1,
      );

      expect(result, -1);
    });

    test('catchError() delegates to inner.catchError', () async {
      final frozen = FrozenFuture<int>(
        Future<int>.error('boom'),
      );

      final result = await frozen.catchError((Object _) => 7);

      expect(result, 7);
    });

    test('catchError() forwards the test predicate to inner', () async {
      final frozen = FrozenFuture<int>(
        Future<int>.error(const FormatException('bad')),
      );

      var checkedError = false;
      final result = await frozen.catchError(
        (Object _) => 1,
        test: (error) {
          checkedError = true;
          return error is FormatException;
        },
      );

      expect(checkedError, isTrue);
      expect(result, 1);
    });

    test('whenComplete() delegates to inner.whenComplete', () async {
      var ran = false;
      final frozen = FrozenFuture<int>(Future<int>.value(1));

      final result = await frozen.whenComplete(() => ran = true);

      expect(ran, isTrue);
      expect(result, 1);
    });

    test('asStream() delegates to inner.asStream', () async {
      final frozen = FrozenFuture<int>(Future<int>.value(99));

      final values = await frozen.asStream().toList();

      expect(values, [99]);
    });

    test(
      'timeout() delegates to inner.timeout and resolves before the limit',
      () async {
        final frozen = FrozenFuture<int>(
          Future<int>.delayed(
            const Duration(milliseconds: 10),
            () => 5,
          ),
        );

        final result = await frozen.timeout(const Duration(seconds: 1));

        expect(result, 5);
      },
    );

    test(
      'timeout() invokes onTimeout when inner exceeds the limit',
      () async {
        final frozen = FrozenFuture<int>(
          Future<int>.delayed(
            const Duration(seconds: 1),
            () => 5,
          ),
        );

        final result = await frozen.timeout(
          const Duration(milliseconds: 10),
          onTimeout: () => -1,
        );

        expect(result, -1);
      },
    );
  });
}
