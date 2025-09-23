import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Stream<UserModel> getUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots()
        .map((snapshot) => UserModel.fromMap(snapshot.data()!));
  }

  Future<void> updateUserProgress(String uid, Map<String, dynamic> progress) async {
    await _firestore.collection('users').doc(uid).update({
      'progress': progress,
    });
  }
}
