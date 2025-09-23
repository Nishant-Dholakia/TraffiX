import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'message_bubble.dart';
import 'typing_indicator.dart';
import 'soundplay.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_moving_background/flutter_moving_background.dart';
import 'package:flutter_moving_background/enums/animation_types.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './screens/auth/login_screen.dart'; // Make sure you have a login page

class ChatBot extends StatefulWidget {
  final String? initialMessage;
  const ChatBot({super.key, this.initialMessage});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    if (user != null) {
      _loadChatHistory();
    }

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _controller.text = widget.initialMessage!;
      Future.delayed(const Duration(milliseconds: 100), () => sendMessage());
    }
  }

  /// Store message in Firestore
  Future<void> storeMessage(String sender, String text) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('messages')
        .add({
      'sender': sender,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Load chat history from Firestore
  Future<void> _loadChatHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    final history = snapshot.docs.map((doc) {
      return {
        'sender': doc['sender'] as String,
        'text': doc['text'] as String,
      };
    }).toList();

    setState(() {
      _messages.addAll(history);
    });

    _scrollToBottom();
  }

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

  Future<void> sendMessage() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      _focusNode.requestFocus();
    });

    setState(() {
      _messages.add({"sender": "user", "text": message});
      _isTyping = true;
      _isLoading = true;
    });
    SoundManager.playSend();
    _scrollToBottom();

    await storeMessage("user", message);

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/ask"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"question": message}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final botReply = data["answer"];

        setState(() {
          _isTyping = false;
          _isLoading = false;
          _messages.add({"sender": "bot", "text": botReply});
        });
        SoundManager.playReceive();
        _scrollToBottom();

        await storeMessage("bot", botReply);

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

  Future<void> translateMessage(int index, String targetLang) async {
    final originalText = _messages[index]["text"];
    setState(() {
      _isLoading = true;
    });

    try {
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
    } catch (_) {
      setState(() {
        _messages[index]["text"] = "Translation failed";
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  /// Logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LingoSnap Chat"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          )
        ],
      ),
      body: Stack(
        children: [
          MovingBackground(
            duration: const Duration(seconds: 2),
            animationType: AnimationType.mixed,
            backgroundColor: Colors.white,
            circles: const [
              MovingCircle(color: Colors.purple),
              MovingCircle(color: Colors.blueAccent),
              MovingCircle(color: Colors.grey),
              MovingCircle(color: Colors.lightBlue),
            ],
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
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
                        onTranslate: isUser
                            ? null
                            : (lang) => translateMessage(index, lang),
                      );
                    },
                  ),
                ),
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Type or speak...",
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : Colors.white,
                          ),
                          onPressed: _listen,
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
