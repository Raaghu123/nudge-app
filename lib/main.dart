import 'package:flutter/material.dart';

void main() {
  runApp(const NudgeApp());
}

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nudge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C7DF0)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Phase 0 placeholder. Phase 1 replaces this with the reminder home screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nudge')),
      body: const SizedBox.expand(),
    );
  }
}
