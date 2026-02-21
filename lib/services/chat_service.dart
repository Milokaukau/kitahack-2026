import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage(String receiverId, String message) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('chat_rooms').doc('temp_room').collection('messages').add({
      'senderId': currentUserId,
      'message': message,
      'timestamp': Timestamp.now(),
    });
  }
}