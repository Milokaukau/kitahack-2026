import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../persona.dart';

class ChatService {
  late final GenerativeModel _model;
  late ChatSession _chatSession;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. CHANGED: Dynamically get the currently logged-in user's UID
  String get currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not logged in!");
    }
    return user.uid;
  }

  Future<void> initialize() async {
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(chatBotPersona),
      tools: [
        Tool.googleSearch(),
      ],
    );

    await _loadHistory();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _loadHistory() async {
    try {
      // 2. CHANGED: Use currentUserId instead of userId
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(currentUserId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      List<Content> history = [];

      if (snapshot.docs.isNotEmpty) {
        history = snapshot.docs.map((doc) {
          final data = doc.data();
          final text = data['text'] ?? '';
          final isUser = data['isUser'] ?? false;

          return isUser
              ? Content.text(text)
              : Content.model([TextPart(text)]);
        }).toList().reversed.toList();
      }

      _chatSession = _model.startChat(history: history);
      print("✅ AI Memory Loaded for User: $currentUserId");
    } catch (e) {
      print("❌ Error loading memory: $e");
      _chatSession = _model.startChat();
    }
  }

  Stream<QuerySnapshot> getMessagesStream() {
    // 3. CHANGED: Use currentUserId instead of userId
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(currentUserId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String text) async {
    // 4. CHANGED: Use currentUserId instead of userId
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(currentUserId)
        .collection('messages')
        .add({
      'text': text,
      'isUser': true,
      'timestamp': FieldValue.serverTimestamp(),
      'sender': "User",
    });

    try {
      final response = await _chatSession.sendMessage(
        Content.text(text),
      );

      final aiReply = response.text ?? "I'm speechless!";

      // 5. CHANGED: Use currentUserId instead of userId
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(currentUserId)
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