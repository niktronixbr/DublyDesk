import 'dart:async';
import 'package:flutter/material.dart';

class ColdStartLoadingWidget extends StatefulWidget {
  const ColdStartLoadingWidget({super.key});

  @override
  State<ColdStartLoadingWidget> createState() =>
      _ColdStartLoadingWidgetState();
}

class _ColdStartLoadingWidgetState extends State<ColdStartLoadingWidget> {
  String? _message;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _timers.addAll([
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _message = 'Conectando ao servidor...');
      }),
      Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _message = 'O servidor está acordando, aguarde...');
        }
      }),
      Timer(const Duration(seconds: 20), () {
        if (mounted) {
          setState(
            () => _message =
                'Isso pode levar até 30 segundos na primeira vez.',
          );
        }
      }),
    ]);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (_message != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
