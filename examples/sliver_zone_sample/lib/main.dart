import 'dart:convert';

import 'package:async_zone/async_zone.dart';
import 'package:error_boundary/error_boundary.dart';
import 'package:flutter/material.dart';
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
      title: 'SliverZoneWidget sample',
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

  void _setId(int nextId) => setState(() => _id = nextId);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 24,
        children: [
          const Text(
            'SliverZoneWidget sample',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          ErrorBoundary(
            onReset: (_) => _setId(1),
            builder: (context, error, reset) =>
                _ErrorCard(error: error, onRetry: reset),
            child: AsyncZone(
              fallback: const CircularProgressIndicator(),
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [_UserCard(id: _id)],
              ),
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
    );
  }
}

class _UserCard extends SliverStatefulZoneWidget {
  const _UserCard({required this.id});

  final int id;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late Future<User> _future = fetchUser(widget.id);

  @override
  void didUpdateWidget(covariant _UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _future = fetchUser(widget.id);
    }
  }

  void _refresh() {
    setState(() {
      _future = fetchUser(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AsyncZone.of(context).use(_future);
    return SliverToBoxAdapter(
      child: Center(
        child: _Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user.email,
                style: const TextStyle(color: Color(0xFF444444)),
              ),
              Text(
                'user #${user.id}',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
              FilledButton.tonal(
                onPressed: _refresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
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
    return Center(
      child: _Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
