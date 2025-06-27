// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

class HackerEffectPopup extends StatefulWidget {
  final VoidCallback onComplete;

  const HackerEffectPopup({super.key, required this.onComplete});

  @override
  _HackerEffectPopupState createState() => _HackerEffectPopupState();
}

class _HackerEffectPopupState extends State<HackerEffectPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _textAnimation;
  final String _hackerText = "Please Register to Continue...";
  final String _hackerSubtitle = "Connecting to secure servers...";
  final int _animationSpeed = 100; // Milliseconds between each character

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: _hackerText.length * _animationSpeed),
      vsync: this,
    );
    _textAnimation = IntTween(begin: 0, end: _hackerText.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Text(
                  _hackerText.substring(0, _textAnimation.value),
                  style: const TextStyle(
                    fontFamily: 'Courier', // Monospaced font
                    fontSize: 18,
                    color: Colors.green,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              _hackerSubtitle,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
