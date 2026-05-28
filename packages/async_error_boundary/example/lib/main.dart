import 'package:async_error_boundary/async_error_boundary.dart';
import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _shouldCrash = true;

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      onReset: (_) => setState(() => _shouldCrash = false),
      builder: (context, error, reset) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Caught: $error'),
          const SizedBox(height: 12),
          FilledButton(onPressed: reset, child: const Text('Reset')),
        ],
      ),
      child: _Crasher(shouldCrash: _shouldCrash),
    );
  }
}

class _Crasher extends ZoneWidget {
  const _Crasher({required this.shouldCrash});

  final bool shouldCrash;

  @override
  Widget build(BuildContext context) {
    if (shouldCrash) throw Exception('boom');
    return const Text('All good', style: TextStyle(fontSize: 20));
  }
}
