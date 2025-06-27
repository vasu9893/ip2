// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

class HackerEffectPopup extends StatelessWidget {
  final VoidCallback onComplete;

  const HackerEffectPopup({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Text("Hacker Effect in Progress..."),
      actions: [
        TextButton(
          onPressed: onComplete,
          child: const Text("Close"),
        ),
      ],
    );
  }
}
