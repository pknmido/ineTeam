import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';

/// Wraps MatchService with business logic validation.
class MatchRepository {
  final MatchService _matchService;

  MatchRepository({MatchService? matchService})
      : _matchService = matchService ?? MatchService();

  /// Creates a match and auto-adds the creator as the first player.
  Future<void> createMatch(MatchModel match) async {
    // Validate the match
    if (match.maxPlayers < 2) {
      throw MatchRepositoryException('Match must have at least 2 players.');
    }
    if (match.dateTime.isBefore(DateTime.now())) {
      throw MatchRepositoryException('Match date must be in the future.');
    }
    if (match.location.trim().isEmpty) {
      throw MatchRepositoryException('Location is required.');
    }

    // Check availability
    final isAvailable = await _matchService.isFieldAvailable(
      match.location,
      match.dateTime,
    );
    if (!isAvailable) {
      throw MatchRepositoryException(
          'This location is already booked at that time. Please pick another.');
    }

    await _matchService.createMatch(match);

    // Update user's createdMatches array
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(match.creatorId)
        .update({
      'createdMatches': FieldValue.arrayUnion([match.id]),
    });
  }

  Future<void> updateMatchStatus(String matchId, String status) async {
    await _matchService.updateMatchStatus(matchId, status);
  }

  Future<void> updateScore(String matchId, int scoreA, int scoreB) async {
    await _matchService.updateScore(matchId, scoreA, scoreB);
  }

  /// Joins a match with validation.
  Future<void> joinMatch(String matchId, String userId, String teamId) async {
    final success = await _matchService.joinMatch(matchId, userId, teamId);
    if (!success) {
      throw MatchRepositoryException(
          'Cannot join this match. It may be full or you are already in it.');
    }

    // Update user's joinedMatches array
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(userId)
        .update({
      'joinedMatches': FieldValue.arrayUnion([matchId]),
    });
  }

  /// Leaves a match.
  Future<void> leaveMatch(String matchId, String userId) async {
    await _matchService.leaveMatch(matchId, userId);

    // Update user's joinedMatches array
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(userId)
        .update({
      'joinedMatches': FieldValue.arrayRemove([matchId]),
    });
  }

  /// Deletes a match (only the creator should call this).
  /// Also removes the match from the creator's createdMatches array.
  Future<void> deleteMatch(String matchId) async {
    // Fetch match first to get creatorId
    final match = await _matchService.getMatchById(matchId);
    await _matchService.deleteMatch(matchId);
    if (match != null) {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(match.creatorId)
          .update({
        'createdMatches': FieldValue.arrayRemove([matchId]),
      });
    }
  }

  /// Real-time stream of all open matches.
  Stream<List<MatchModel>> matchesStream() => _matchService.matchesStream();

  /// Real-time stream of a single match.
  Stream<MatchModel?> matchStream(String matchId) =>
      _matchService.matchStream(matchId);

  /// Fetches a single match.
  Future<MatchModel?> getMatchById(String matchId) =>
      _matchService.getMatchById(matchId);

  /// Matches the user has joined.
  Stream<List<MatchModel>> userMatchesStream(String userId) =>
      _matchService.userMatchesStream(userId);

  /// Matches the user created.
  Stream<List<MatchModel>> createdMatchesStream(String userId) =>
      _matchService.createdMatchesStream(userId);
}

/// Custom exception for match repository errors.
class MatchRepositoryException implements Exception {
  final String message;
  const MatchRepositoryException(this.message);

  @override
  String toString() => message;
}
