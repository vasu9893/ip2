// ignore_for_file: file_names, use_key_in_widget_constructors

import 'package:flutter/material.dart';

class RegisterPopup extends StatelessWidget {
  final VoidCallback onClose;

  const RegisterPopup({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Register"),
      content: const Text("Please register to continue."),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text("Close"),
        ),
      ],
    );
  }
}
