import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';

Future<String> fetchGreeting() async {
  await Future.delayed(const Duration(seconds: 2));
  return 'Hello, async_zone!';
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

class _Greeting extends StatefulZoneWidget {
  const _Greeting();

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  late final Future<String> _greeting = fetchGreeting();

  @override
  Widget build(BuildContext context) {
    final message = AsyncZone.of(context).use(_greeting);
    return Text(message, style: const TextStyle(fontSize: 20));
  }
}
