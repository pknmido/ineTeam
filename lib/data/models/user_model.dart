import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile stored in Firestore.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? profilePictureUrl;
  final List<String> sports;
  final int skillLevel; // 1-100 (legacy / overall default)
  final Map<String, int> sportRatings; // per-sport skill level, e.g. {'Football': 60, 'Basketball': 40}
  final String frequency; // 'casual' | 'regular' | 'competitive'
  final List<String> createdMatches;
  final List<String> joinedMatches;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    this.sports = const [],
    this.skillLevel = 50,
    this.sportRatings = const {},
    this.frequency = 'casual',
    this.createdMatches = const [],
    this.joinedMatches = const [],
    required this.createdAt,
  });

  /// Creates a UserModel from a Firestore document map.
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final email = map['email']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';
    // If name is empty (legacy accounts), fallback to email prefix so they can complete profile
    final displayName = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email.split('@').first : 'Player');

    // Parse per-sport ratings map
    Map<String, int> sportRatings = {};
    final rawRatings = map['sportRatings'];
    if (rawRatings is Map) {
      rawRatings.forEach((k, v) {
        if (k is String && v is int) {
          sportRatings[k] = v;
        }
      });
    }

    return UserModel(
      uid: uid,
      name: displayName,
      email: email,
      profilePictureUrl: map['profilePictureUrl'],
      sports: List<String>.from(map['sports'] ?? []),
      skillLevel: map['skillLevel'] ?? 50,
      sportRatings: sportRatings,
      frequency: map['frequency'] ?? 'casual',
      createdMatches: List<String>.from(map['createdMatches'] ?? []),
      joinedMatches: List<String>.from(map['joinedMatches'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this model to a Firestore-ready map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'sports': sports,
      'skillLevel': skillLevel,
      'sportRatings': sportRatings,
      'frequency': frequency,
      'createdMatches': createdMatches,
      'joinedMatches': joinedMatches,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Creates a copy with optional overrides.
  UserModel copyWith({
    String? name,
    String? email,
    String? profilePictureUrl,
    List<String>? sports,
    int? skillLevel,
    Map<String, int>? sportRatings,
    String? frequency,
    List<String>? createdMatches,
    List<String>? joinedMatches,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      sports: sports ?? this.sports,
      skillLevel: skillLevel ?? this.skillLevel,
      sportRatings: sportRatings ?? this.sportRatings,
      frequency: frequency ?? this.frequency,
      createdMatches: createdMatches ?? this.createdMatches,
      joinedMatches: joinedMatches ?? this.joinedMatches,
      createdAt: createdAt,
    );
  }

  /// Whether the user has completed their profile setup.
  bool get hasCompletedProfile => name.isNotEmpty && sports.isNotEmpty;

  /// Returns the skill rating for a specific sport, falling back to skillLevel.
  int ratingForSport(String sport) => sportRatings[sport] ?? skillLevel;
}
