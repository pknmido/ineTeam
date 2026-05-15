import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a sports match stored in Firestore.
class MatchModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String sport;
  final String location;
  final DateTime dateTime;
  final int maxPlayers;
  final List<String> playerIds;
  final List<String> teamA;
  final List<String> teamB;
  final String teamAName;
  final String teamBName;
  final String? description;
  final int? minSkill;
  final int? maxSkill;
  final String status; // 'open' | 'full' | 'completed'
  final DateTime createdAt;
  final int? scoreA;
  final int? scoreB;

  const MatchModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.sport,
    required this.location,
    required this.dateTime,
    required this.maxPlayers,
    this.playerIds = const [],
    this.teamA = const [],
    this.teamB = const [],
    this.teamAName = 'Team A',
    this.teamBName = 'Team B',
    this.description,
    this.minSkill,
    this.maxSkill,
    this.status = 'open',
    required this.createdAt,
    this.scoreA,
    this.scoreB,
  });

  /// Creates a MatchModel from a Firestore document map.
  factory MatchModel.fromMap(Map<String, dynamic> map, String id) {
    return MatchModel(
      id: id,
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      sport: map['sport'] ?? '',
      location: map['location'] ?? '',
      dateTime: (map['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxPlayers: map['maxPlayers'] ?? 10,
      playerIds: List<String>.from(map['playerIds'] ?? []),
      teamA: List<String>.from(map['teamA'] ?? []),
      teamB: List<String>.from(map['teamB'] ?? []),
      teamAName: map['teamAName'] ?? 'Team A',
      teamBName: map['teamBName'] ?? 'Team B',
      description: map['description'],
      minSkill: map['minSkill'],
      maxSkill: map['maxSkill'],
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scoreA: map['scoreA'],
      scoreB: map['scoreB'],
    );
  }

  /// Converts this model to a Firestore-ready map.
  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'sport': sport,
      'location': location,
      'dateTime': Timestamp.fromDate(dateTime),
      'maxPlayers': maxPlayers,
      'playerIds': playerIds,
      'teamA': teamA,
      'teamB': teamB,
      'teamAName': teamAName,
      'teamBName': teamBName,
      'description': description,
      'minSkill': minSkill,
      'maxSkill': maxSkill,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'scoreA': scoreA,
      'scoreB': scoreB,
    };
  }

  /// Creates a copy with optional overrides.
  MatchModel copyWith({
    String? creatorId,
    String? creatorName,
    String? sport,
    String? location,
    DateTime? dateTime,
    int? maxPlayers,
    List<String>? playerIds,
    List<String>? teamA,
    List<String>? teamB,
    String? teamAName,
    String? teamBName,
    String? description,
    int? minSkill,
    int? maxSkill,
    String? status,
    int? scoreA,
    int? scoreB,
  }) {
    return MatchModel(
      id: id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      sport: sport ?? this.sport,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      playerIds: playerIds ?? this.playerIds,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      description: description ?? this.description,
      minSkill: minSkill ?? this.minSkill,
      maxSkill: maxSkill ?? this.maxSkill,
      status: status ?? this.status,
      createdAt: createdAt,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
    );
  }

  /// Whether the match is full.
  bool get isFull => playerIds.length >= maxPlayers;

  /// Whether a specific user has joined.
  bool hasPlayer(String userId) => playerIds.contains(userId);

  /// Current player count.
  int get playerCount => playerIds.length;

  /// Spots remaining.
  int get spotsLeft => maxPlayers - playerIds.length;

  /// Whether the match is in the future.
  bool get isUpcoming => dateTime.isAfter(DateTime.now());

  /// Whether a score has been recorded.
  bool get hasScore => scoreA != null && scoreB != null;

  /// Whether the given user is the creator.
  bool isCreator(String userId) => creatorId == userId;
}
