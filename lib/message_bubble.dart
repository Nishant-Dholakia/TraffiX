import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const MessageBubble({Key? key, required this.text, required this.isUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: isUser
            ? Text(
                text,
                style: const TextStyle(color: Colors.white),
              )
            : AnimatedTextKit(
                totalRepeatCount: 1,
                isRepeatingAnimation: false,
                animatedTexts: [
                  TypewriterAnimatedText(
                    text,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    speed: const Duration(milliseconds: 50),
                  ),
                ],
              ),
      ),
    );
  }
}
