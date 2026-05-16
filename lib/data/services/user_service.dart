import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Handles Firestore and Storage operations for user profiles.
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get usersCollection =>
      _firestore.collection(FirestoreCollections.users);

  /// Creates a new user profile document in Firestore.
  Future<void> createUserProfile(UserModel user) async {
    await usersCollection.doc(user.uid).set(user.toMap());
  }

  /// Fetches a user profile by UID.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
  }

  /// Updates specific fields of a user profile.
  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    await usersCollection.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Real-time stream of the user's profile.
  Stream<UserModel?> userProfileStream(String uid) {
    return usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
    });
  }

  /// Uploads a profile picture to Firebase Storage and returns the URL.
  Future<String> uploadProfilePicture(String uid, File file) async {
    final ref = _storage.ref().child('profile_pictures/$uid.jpg');
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await uploadTask.ref.getDownloadURL();

    // Also update the user's profile document
    await updateUserProfile(uid, {'profilePictureUrl': url});
    return url;
  }

  /// Fetches multiple user profiles by their UIDs.
  /// Useful for displaying player lists in match details.
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    // Firestore 'whereIn' is limited to 30 items per query
    final List<UserModel> users = [];
    for (var i = 0; i < uids.length; i += 30) {
      final batch = uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
      final snapshot = await usersCollection
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        users.add(
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id));
      }
    }
    return users;
  }

  /// Mutual unfriending between two users.
  Future<void> unfriend(String userId, String friendId) async {
    final batch = _firestore.batch();
    
    final userRef = usersCollection.doc(userId);
    final friendRef = usersCollection.doc(friendId);
    
    batch.update(userRef, {
      'friends': FieldValue.arrayRemove([friendId]),
    });
    
    batch.update(friendRef, {
      'friends': FieldValue.arrayRemove([userId]),
    });
    
    await batch.commit();
  }
}
