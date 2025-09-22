import 'package:flutter/material.dart';
import 'chatbot.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_moving_background/flutter_moving_background.dart';
import 'package:flutter_moving_background/enums/animation_types.dart';
class TrafficApp extends StatefulWidget {
  const TrafficApp({super.key});

  @override
  State<TrafficApp> createState() => _TrafficAppState();
}

class _TrafficAppState extends State<TrafficApp> {
  final TextEditingController _inputController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final List<String> suggestedQuestions = [
    "What are the traffic rules for pedestrians?",
    "How to pay traffic fines?",
    "Speed limits in city areas?",
    "How to report traffic violations?"
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _inputController.text = result.recognizedWords;
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _navigateToChatBot() {
    if (_inputController.text.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatBot(
            initialMessage: _inputController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Moving background
          MovingBackground(
            duration: const Duration(seconds: 2),
            animationType: AnimationType.mixed,
            backgroundColor: Colors.black87,
            circles: const [
              MovingCircle(color: Colors.purple,),
              MovingCircle(color: Colors.blueAccent),
              MovingCircle(color: Colors.grey),
              MovingCircle(color: Colors.lightBlue),
            ],
            child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header
                      const Center(
                        child: Text(
                          "Traffix",
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Description
                      const Center(
                        child: Text(
                          "Your smart assistant for traffic rules, fines, and road safety tips.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Input + Mic + Search buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              decoration: InputDecoration(
                                hintText: "Ask about traffic...",
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Microphone Button
                          Container(
                            decoration: BoxDecoration(
                              color: _isListening ? Colors.red : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.mic,
                                color: _isListening ? Colors.white : Colors.grey[700],
                              ),
                              onPressed: _listen,
                              tooltip: _isListening ? 'Stop listening' : 'Start voice input',
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Search Button
                          ElevatedButton(
                            onPressed: _navigateToChatBot,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                            ),
                            child: const Text("Search"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_isListening)
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text(
                                "Listening... Speak now",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Popular Questions:",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: suggestedQuestions
                            .map(
                              (q) => ActionChip(
                            backgroundColor: Colors.white,
                            label: Text(q, style: const TextStyle(color: Colors.black87)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatBot(initialMessage: q),
                                ),
                              );
                            },
                          ),
                        )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mic, color: Colors.black54, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Tap the microphone icon to ask your question using voice",
                                style: TextStyle(
                                  color: Colors.black54.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _inputController.dispose();
    super.dispose();
  }
}
