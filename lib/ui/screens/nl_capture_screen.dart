import 'package:flutter/material.dart' hide Category;
import 'package:nudge/services/nl_parser.dart';
import 'package:nudge/ui/screens/nl_confirm_screen.dart';

/// Natural-language capture: the user types what they want to remember,
/// taps Preview, and the parsed result opens on [NlConfirmScreen].
class NlCaptureScreen extends StatefulWidget {
  const NlCaptureScreen({super.key});

  @override
  State<NlCaptureScreen> createState() => _NlCaptureScreenState();
}

class _NlCaptureScreenState extends State<NlCaptureScreen> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _preview() {
    final text = _inputController.text.trim();
    // The empty state is obvious enough; no error message.
    if (text.length < 3) return;
    final parsed = NlParser.parse(_inputController.text);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NlConfirmScreen(parsed: parsed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nudge')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('nl_input'),
              controller: _inputController,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What do you want to remember?',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Visual only: voice input is a later phase.
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('nl_preview'),
              onPressed: _preview,
              child: const Text('Preview'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try: remind me to take my thyroid pill every morning and night',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
