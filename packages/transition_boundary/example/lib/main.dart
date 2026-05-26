import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';
import 'package:transition_boundary/transition_boundary.dart';

Future<String> fetchProfile(int id) async {
  await Future.delayed(const Duration(seconds: 1));
  return 'Profile #$id';
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
    return const TransitionBoundary(child: _Switcher());
  }
}

class _Switcher extends StatefulWidget {
  const _Switcher();

  @override
  State<_Switcher> createState() => _SwitcherState();
}

class _SwitcherState extends State<_Switcher> {
  int _id = 1;
  late Future<String> _profile = fetchProfile(_id);

  @override
  Widget build(BuildContext context) {
    final scope = TransitionZone.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AsyncZone(
          fallback: const CircularProgressIndicator(),
          child: _Profile(future: _profile),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => scope.startTransition(() {
            setState(() {
              _id++;
              _profile = fetchProfile(_id);
            });
          }),
          child: Text(scope.isPending ? 'Loading…' : 'Next'),
        ),
      ],
    );
  }
}

class _Profile extends ZoneWidget {
  const _Profile({required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final name = AsyncZone.of(context).use(future);
    return Text(name, style: const TextStyle(fontSize: 20));
  }
}
