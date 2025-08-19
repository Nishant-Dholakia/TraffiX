import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'message_bubble.dart';
import 'typing_indicator.dart';
import 'soundplay.dart';


class ChatBot extends StatefulWidget {
  const ChatBot({Key? key}) : super(key: key);

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  Future<void> sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": message});
      _isTyping = true;
    });
    _controller.clear();
    SoundManager.playSend();

    final response = await http.post(
      Uri.parse("https://5cb8154cdd29.ngrok-free.app/ask"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"question": message}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _isTyping = false;
        _messages.add({"sender": "bot", "text": data["answer"]});
      });
      SoundManager.playReceive();
    } else {
      setState(() {
        _isTyping = false;
        _messages.add({"sender": "bot", "text": "Error: Could not connect"});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isTyping && index == _messages.length) {
                return const TypingIndicator();
              }
              final msg = _messages[index];
              final isUser = msg["sender"] == "user";
              return MessageBubble(text: msg["text"]!, isUser: isUser);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendMessage,
              )
            ],
          ),
        )
      ],
    );
  }
}
