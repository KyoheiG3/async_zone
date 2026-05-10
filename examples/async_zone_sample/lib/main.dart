import 'dart:convert';

import 'package:async_zone/async_zone.dart';
import 'package:error_boundary/error_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const App());

class User {
  const User({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}

Future<User> fetchUser(int id) async {
  await Future.delayed(const Duration(seconds: 2));
  final res = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/users/$id'),
  );
  if (res.statusCode != 200) {
    throw 'Failed to fetch user $id: ${res.statusCode}';
  }
  return User.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suspense + use() sample',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: SafeArea(child: SamplePage())),
    );
  }
}

class SamplePage extends HookWidget {
  const SamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final id = useState(1);
    final userFuture = useState(useMemoized(() => fetchUser(1)));

    void loadUser(int nextId) {
      id.value = nextId;
      userFuture.value = fetchUser(nextId);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 24,
          children: [
            const Text(
              'Suspense + use() sample',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            ErrorBoundary(
              builder: (context, error, reset) => _ErrorCard(
                error: error,
                onRetry: () {
                  reset();
                  loadUser(1);
                },
              ),
              child: AsyncZone(
                fallback: CircularProgressIndicator(),
                child: UserCard(userFuture: userFuture.value),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: id.value <= 1
                      ? null
                      : () => loadUser(id.value - 1),
                  child: const Text('Prev'),
                ),
                FilledButton.tonal(
                  onPressed: () => loadUser(id.value + 1),
                  child: const Text('Next'),
                ),
                FilledButton.tonal(
                  onPressed: () => userFuture.value = fetchUser(99999),
                  child: const Text('Force error'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserCard extends HookZoneWidget {
  const UserCard({super.key, required this.userFuture});

  final Future<User> userFuture;

  @override
  Widget build(BuildContext context) {
    final user = useAsyncZone().use(userFuture);
    return _Card(
      child: Column(
        spacing: 4,
        children: [
          Text(
            user.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(user.email, style: const TextStyle(color: Color(0xFF444444))),
          Text(
            'user #${user.id}',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        spacing: 8,
        children: [
          Text(
            'Error: $error',
            style: const TextStyle(color: Color(0xFFB00020)),
            textAlign: TextAlign.center,
          ),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 240),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
