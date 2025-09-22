import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Function(String)? onTranslate; // callback for translation

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onTranslate,
  });

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ==== Message text ====
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
            ),

            // ==== Translate Dropdown (only for bot messages) ====
            if (!isUser && onTranslate != null)
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.translate,
                    size: 20,
                    color: Colors.black54,
                  ),
                  onSelected: (lang) => onTranslate!(lang),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: "en", child: Text("English")),
                    PopupMenuItem(value: "hi", child: Text("Hindi")),
                    PopupMenuItem(value: "fr", child: Text("French")),
                    PopupMenuItem(value: "es", child: Text("Spanish")),
                    PopupMenuItem(value: "gu", child: Text("Gujarati")),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
