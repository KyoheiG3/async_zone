import 'dart:convert';

import 'package:async_zone/async_zone.dart';
import 'package:async_error_boundary/async_error_boundary.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:transition_boundary/transition_boundary.dart';

void main() => runApp(const App());

class User {
  const User({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: '${json['firstName']} ${json['lastName']}',
    email: json['email'] as String,
  );
}

Future<User> fetchUser(int id) async {
  await Future.delayed(const Duration(seconds: 2));
  final res = await http.get(Uri.parse('https://dummyjson.com/users/$id'));
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
      home: const Scaffold(
        body: SafeArea(child: TransitionBoundary(child: SamplePage())),
      ),
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
  Future<User> _userFuture = fetchUser(1);

  void _loadUser(int nextId) {
    TransitionZone.of(context).startTransition(() {
      setState(() {
        _id = nextId;
        _userFuture = fetchUser(nextId);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final transition = TransitionZone.of(context);
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
            onReset: (_) => _loadUser(1),
            builder: (context, error, reset) =>
                _ErrorCard(error: error, onRetry: reset),
            child: AsyncZone(
              fallback: const CircularProgressIndicator(),
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverOpacity(
                    opacity: transition.isPending ? 0.5 : 1.0,
                    sliver: _UserCard(userFuture: _userFuture),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              FilledButton.tonal(
                onPressed: (transition.isPending || _id <= 1)
                    ? null
                    : () => _loadUser(_id - 1),
                child: const Text('Prev'),
              ),
              FilledButton.tonal(
                onPressed: transition.isPending
                    ? null
                    : () => _loadUser(_id + 1),
                child: const Text('Next'),
              ),
              FilledButton.tonal(
                onPressed: () => transition.startTransition(() {
                  setState(() {
                    _userFuture = fetchUser(99999);
                  });
                }),
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
  const _UserCard({required this.userFuture});

  final Future<User> userFuture;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  @override
  Widget build(BuildContext context) {
    final user = AsyncZone.of(context).use(widget.userFuture);
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
