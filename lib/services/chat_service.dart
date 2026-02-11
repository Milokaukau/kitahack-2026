import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../persona.dart'; // Import your persona

class ChatService {
  late final GenerativeModel _model;
  late ChatSession _chatSession;
  final String userId = 'test_user'; // Hardcoded for now, can be dynamic later

  // Initialize the model and session
  Future<void> initialize() async {
    // 1. Setup Model
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(chatBotPersona),
      tools: [
        Tool.googleSearch(),
      ],
    );

    // 2. Load History for Context
    await _loadHistory();
  }

  // Load last 10 messages to give Gemini context
  Future<void> _loadHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      List<Content> history = [];

      if (snapshot.docs.isNotEmpty) {
        // Map Firestore data to Gemini Content objects
        history = snapshot.docs.map((doc) {
          final data = doc.data();
          final text = data['text'] ?? '';
          final isUser = data['isUser'] ?? false;

          // Correctly format history for Gemini
          return isUser
              ? Content.text(text)
              : Content.model([TextPart(text)]);
        }).toList().reversed.toList();
      }

      _chatSession = _model.startChat(history: history);
      print("✅ AI Memory Loaded.");
    } catch (e) {
      print("❌ Error loading memory: $e");
      _chatSession = _model.startChat();
    }
  }

  // Get the stream of messages for the UI
  Stream<QuerySnapshot> getMessagesStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Handle sending a message
  Future<void> sendMessage(String text) async {
    // 1. Save User Message to DB
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(userId)
        .collection('messages')
        .add({
      'text': text,
      'isUser': true,
      'timestamp': FieldValue.serverTimestamp(),
      'sender': "User",
    });

    try {
      // 2. Send to Gemini
      final response = await _chatSession.sendMessage(
        Content.text(text),
      );

      final aiReply = response.text ?? "I'm speechless!";

      // 3. Save AI Reply to DB
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(userId)
          .collection('messages')
          .add({
        'text': aiReply,
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': "AI Companion",
      });
    } catch (e) {
      print("Error talking to Gemini: $e");
    }
  }
}