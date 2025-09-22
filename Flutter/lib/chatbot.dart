import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'message_bubble.dart';
import 'typing_indicator.dart';
import 'soundplay.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatBot extends StatefulWidget {
  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController(); // ✅ For auto-scroll
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  /// Auto-scroll helper
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Start / stop voice listening
  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  /// Send message to backend
  Future<void> sendMessage() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }

    final message = _controller.text.trim();
    if (message.isEmpty) return;

    // ✅ Proper clear (no highlight)
    _controller.clear();
    _controller.selection = const TextSelection.collapsed(offset: 0);
    FocusScope.of(context).unfocus(); // remove highlight
    Future.delayed(const Duration(milliseconds: 50), () {
      _focusNode.requestFocus(); // refocus nicely
    });

    setState(() {
      _messages.add({"sender": "user", "text": message});
      _isTyping = true;
      _isLoading = true;
    });
    SoundManager.playSend();
    _scrollToBottom(); // scroll after sending

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/ask"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"question": message}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isTyping = false;
          _isLoading = false;
          _messages.add({"sender": "bot", "text": data["answer"]});
        });
        SoundManager.playReceive();
        _scrollToBottom(); // scroll after bot reply
      } else {
        setState(() {
          _isTyping = false;
          _isLoading = false;
          _messages.add({"sender": "bot", "text": "Error: Could not connect"});
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _isLoading = false;
        _messages.add({"sender": "bot", "text": "Error: $e"});
      });
      _scrollToBottom();
    }
  }

  /// Translate a message
  Future<void> translateMessage(int index, String targetLang) async {
    final originalText = _messages[index]["text"];
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse("http://127.0.0.1:8000/translate"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"text": originalText, "target_lang": targetLang}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _messages[index]["text"] = " ${data['translated_text']}";
        _isLoading = false;
      });
    } else {
      setState(() {
        _messages[index]["text"] = "Translation failed";
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController, // ✅ attach scroll controller
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return const TypingIndicator();
                  }

                  final msg = _messages[index];
                  final isUser = msg["sender"] == "user";

                  return MessageBubble(
                    text: msg["text"]!,
                    isUser: isUser,
                    onTranslate:
                    isUser ? null : (lang) => translateMessage(index, lang),
                  );
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
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: "Type or speak...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : null,
                    ),
                    onPressed: _listen,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Loader overlay
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
