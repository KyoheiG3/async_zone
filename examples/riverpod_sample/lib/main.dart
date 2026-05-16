import 'dart:convert';

import 'package:async_zone/async_zone.dart';
import 'package:error_boundary/error_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'consumer_zone_widget.dart';
import 'watch_or_suspend.dart';

void main() => runApp(const ProviderScope(child: App()));

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

class FetchUserException implements Exception {
  FetchUserException(this.message);
  final String message;
  @override
  String toString() => message;
}

final userProvider = FutureProvider.family<User, int>((ref, id) async {
  await Future.delayed(const Duration(seconds: 2));
  final res = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/users/$id'),
  );
  if (res.statusCode != 200) {
    throw FetchUserException('Failed to fetch user $id: ${res.statusCode}');
  }
  return User.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
});

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'riverpod sample',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: SafeArea(child: SamplePage())),
    );
  }
}

class SamplePage extends StatefulWidget {
  const SamplePage({super.key});

  @override
  State<SamplePage> createState() => _SamplePageState();
}

class _SamplePageState extends State<SamplePage> {
  int _id = 1;

  void _setId(int next) => setState(() => _id = next);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 24,
          children: [
            const Text(
              'riverpod sample',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            ErrorBoundary(
              builder: (context, error, reset) => _ErrorCard(
                error: error,
                onRetry: () {
                  reset();
                  _setId(1);
                },
              ),
              child: AsyncZone(
                fallback: const CircularProgressIndicator(),
                child: UserCard(id: _id),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: _id <= 1 ? null : () => _setId(_id - 1),
                  child: const Text('Prev'),
                ),
                FilledButton.tonal(
                  onPressed: () => _setId(_id + 1),
                  child: const Text('Next'),
                ),
                FilledButton.tonal(
                  onPressed: () => _setId(99999),
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

class UserCard extends ConsumerZoneWidget {
  const UserCard({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:data, :asyncData) = watchOrSuspend(ref, userProvider(id));
    return _Card(
      child: Column(
        spacing: 8,
        children: [
          Text(
            data.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(data.email, style: const TextStyle(color: Color(0xFF444444))),
          Text(
            'user #${data.id}',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
          FilledButton.tonal(
            onPressed: asyncData.isLoading
                ? null
                : () => ref.invalidate(userProvider(id)),
            child: asyncData.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Refresh'),
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
