import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final void Function(String)? onTranslate;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.isUser,
    this.onTranslate,
  }) : super(key: key);

  // Supported translation languages
  static const Map<String, String> languages = {
    "hi": "Hindi",
    "gu": "Gujarati",
    "fr": "French",
    "es": "Spanish",
    "en" : "English"
  };

  @override
  Widget build(BuildContext context) {
    final bgColor = isUser ? Colors.blue[600] : const Color(0xFFF0F0F0);
    final textColor = isUser ? Colors.white : Colors.black;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Render markdown
            MarkdownBody(
              data: text,
              selectable: true,
              softLineBreak: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                strong: TextStyle(
                    color: textColor, fontWeight: FontWeight.bold),
                em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                code: TextStyle(
                  backgroundColor: Colors.black12,
                  color: Colors.deepPurple,
                  fontFamily: "monospace",
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                codeblockPadding: const EdgeInsets.all(8),
              ),

              // Image rendering fix
              imageBuilder: (uri, title, alt) {
                return Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(2, 2),
                      )
                    ],
                  ),
                  child: Image.network(
                    uri.toString(),
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),

            // ---------- TRANSLATE DROPDOWN (BOT ONLY) ----------
            if (!isUser && onTranslate != null)
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.translate, size: 20),
                  tooltip: "Translate message",
                  onSelected: (langCode) {
                    if (onTranslate != null) onTranslate!(langCode);
                  },
                  itemBuilder: (context) {
                    return languages.entries.map((entry) {
                      return PopupMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
