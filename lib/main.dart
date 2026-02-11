import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart'; // 1. NEW IMPORT
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'persona.dart'; // Your persona file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily AI Bot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatSession _chatSession;
  bool _isLoadingHistory = true;

  // 2. NEW: Setup Model using FirebaseAI
  late final GenerativeModel _model;

  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'Me');
  final ChatUser _aiUser = ChatUser(
      id: '2',
      firstName: 'Daily Bot',
      profileImage: "https://cdn-icons-png.flaticon.com/512/4712/4712027.png"
  );

  @override
  void initState() {
    super.initState();
    _initializeModel(); // Initialize model first
  }

  void _initializeModel() {
    // 3. Use FirebaseAI.googleAI() to use your API Key
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash', // Or 'gemini-2.0-flash'
      systemInstruction: Content.system(chatBotPersona),

      // 4. ENABLE GROUNDING (Search)
      tools: [
        Tool.googleSearch(), // This works natively in firebase_ai!
      ],
    );

    // After model is ready, load history
    _loadMemoryFromDB();
  }

  Future<void> _loadMemoryFromDB() async {
    print("🧠 Loading AI Memory...");

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc('test_user')
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

          if (isUser) {
            return Content.text(text);
          } else {
            return Content.model([TextPart(text)]);
          }
        }).toList().reversed.toList();
      }

      _chatSession = _model.startChat(history: history);
      print("✅ AI Memory Loaded.");

    } catch (e) {
      print("❌ Error loading memory: $e");
      _chatSession = _model.startChat();
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Daily Companion")),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc('test_user')
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<ChatMessage> messages = snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return ChatMessage(
              user: (data['isUser'] ?? false) ? _currentUser : _aiUser,
              text: data['text'] ?? '',
              createdAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();

          return DashChat(
            currentUser: _currentUser,
            messages: messages,
            onSend: (ChatMessage m) {
              _handleSendMessage(m);
            },
            inputOptions: InputOptions(
              inputDecoration: InputDecoration(
                hintText: "Reply to your AI friend...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSendMessage(ChatMessage chatMessage) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc('test_user')
        .collection('messages')
        .add({
      'text': chatMessage.text,
      'isUser': true,
      'timestamp': FieldValue.serverTimestamp(),
      'sender': "User",
    });

    try {
      final response = await _chatSession.sendMessage(
        Content.text(chatMessage.text),
      );

      final aiReply = response.text ?? "I'm speechless!";

      await FirebaseFirestore.instance
          .collection('chats')
          .doc('test_user')
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