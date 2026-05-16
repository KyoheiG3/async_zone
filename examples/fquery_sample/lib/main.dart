import 'dart:convert';

import 'package:async_zone/async_zone.dart';
import 'package:error_boundary/error_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:fquery_core/fquery_core.dart';
import 'package:hooks_async_zone/hooks_async_zone.dart';
import 'package:http/http.dart' as http;

import 'use_async_zone_query.dart';

final queryCache = QueryCache(
  defaultQueryOptions: DefaultQueryOptions(
    enabled: true,
    refetchOnMount: RefetchOnMount.stale,
    staleDuration: Duration.zero,
    cacheDuration: const Duration(minutes: 5),
    refetchInterval: null,
    retryCount: 0,
    retryDelay: const Duration(seconds: 1, milliseconds: 500),
  ),
);

void main() => runApp(CacheProvider(cache: queryCache, child: const App()));

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

Future<User> fetchUser(int id) async {
  await Future.delayed(const Duration(seconds: 2));
  final res = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/users/$id'),
  );
  if (res.statusCode != 200) {
    throw FetchUserException('Failed to fetch user $id: ${res.statusCode}');
  }
  return User.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fquery sample',
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 24,
          children: [
            const Text(
              'fquery sample',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            ErrorBoundary(
              builder: (context, error, reset) => _ErrorCard(
                error: error,
                onRetry: () {
                  reset();
                  id.value = 1;
                },
              ),
              child: AsyncZone(
                fallback: const CircularProgressIndicator(),
                child: UserCard(key: ValueKey(id.value), id: id.value),
                // child: UserCard(id: id.value),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: id.value <= 1 ? null : () => id.value -= 1,
                  child: const Text('Prev'),
                ),
                FilledButton.tonal(
                  onPressed: () => id.value += 1,
                  child: const Text('Next'),
                ),
                FilledButton.tonal(
                  onPressed: () => id.value = 99999,
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
  const UserCard({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final (:data, :query) = useAsyncZoneQuery([
      'user',
      id,
    ], () => fetchUser(id));
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
            onPressed: query.isFetching ? null : query.refetch,
            child: query.isFetching
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
