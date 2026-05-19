import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';

Future<String> fetchGreeting() async {
  await Future.delayed(const Duration(seconds: 2));
  return 'Hello, hooks_async_zone!';
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: HomePage())),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AsyncZone(
      fallback: CircularProgressIndicator(),
      child: _Greeting(),
    );
  }
}

class _Greeting extends HookZoneWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final greeting = useMemoized(fetchGreeting);
    final message = useAsyncZone().use(greeting);
    return Text(message, style: const TextStyle(fontSize: 20));
  }
}
