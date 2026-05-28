import 'package:async_zone/async_zone.dart';
import 'package:flutter/material.dart';

/// Widget that throws a synchronous error on build
class ThrowingWidget extends ZoneWidget {
  const ThrowingWidget({
    super.key,
    this.shouldThrow = true,
    required this.message,
  });

  final bool shouldThrow;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (shouldThrow) {
      throw message;
    }
    return Text('Normal: $message');
  }
}
