import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/match_model.dart';

/// Handles all Firestore operations for matches.
class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _matchesCollection =>
      _firestore.collection(FirestoreCollections.matches);

  /// Creates a new match document.
  /// Creates a new match document.
  Future<void> createMatch(MatchModel match) async {
    await _matchesCollection.doc(match.id).set(match.toMap());
  }

  /// Checks if a field is available at a specific exact time.
  Future<bool> isFieldAvailable(String location, DateTime dateTime) async {
    final query = await _matchesCollection
        .where('location', isEqualTo: location)
        .where('dateTime', isEqualTo: Timestamp.fromDate(dateTime))
        .where('status', whereIn: ['open', 'full'])
        .limit(1)
        .get();

    return query.docs.isEmpty;
  }

  /// Fetches a single match by ID.
  Future<MatchModel?> getMatchById(String matchId) async {
    final doc = await _matchesCollection.doc(matchId).get();
    if (!doc.exists) return null;
    return MatchModel.fromMap(doc.data() as Map<String, dynamic>, matchId);
  }

  /// Returns all reserved date times for a particular location on a specific day.
  Future<List<DateTime>> getReservedTimesForDay(
      String location, DateTime date) async {
    // Only query by location to avoid requiring a composite index setup
    final query = await _matchesCollection
        .where('location', isEqualTo: location)
        .get();

    final reservedTimes = <DateTime>[];

    for (var doc in query.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'open';
      
      // Ignore completed or cancelled matches
      if (status != 'open' && status != 'full') continue;

      final dtRaw = data['dateTime'];
      if (dtRaw == null) continue;

      final dt = (dtRaw as Timestamp).toDate();
      // Check if same day
      if (dt.year == date.year &&
          dt.month == date.month &&
          dt.day == date.day) {
        reservedTimes.add(dt);
      }
    }

    return reservedTimes;
  }

  /// Real-time stream of all open matches, ordered by date.
  Stream<List<MatchModel>> matchesStream() {
    return _matchesCollection
        //.where('status', whereIn: ['open'])
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                MatchModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Real-time stream of a single match for live updates.
  Stream<MatchModel?> matchStream(String matchId) {
    return _matchesCollection.doc(matchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MatchModel.fromMap(doc.data() as Map<String, dynamic>, matchId);
    });
  }

  /// Adds a player to a match explicitly via team logic.
  /// Returns false if the team or match is already full.
  Future<bool> joinMatch(String matchId, String userId, String teamId) async {
    return _firestore.runTransaction<bool>((transaction) async {
      final doc = await transaction.get(_matchesCollection.doc(matchId));
      if (!doc.exists) return false;

      final match = MatchModel.fromMap(doc.data() as Map<String, dynamic>, matchId);

      // Prevent joining a full match or duplicates
      if (match.isFull || match.hasPlayer(userId)) return false;
      
      // Determine max players per team
      final maxPerTeam = match.maxPlayers ~/ 2;
      
      List<String> currentTeamArray;
      if (teamId == 'A') {
        currentTeamArray = match.teamA;
      } else if (teamId == 'B') currentTeamArray = match.teamB;
      else return false;

      // Prevent joining full team
      if (currentTeamArray.length >= maxPerTeam) return false;

      final newPlayerIds = [...match.playerIds, userId];
      final newTeamArray = [...currentTeamArray, userId];
      final newStatus = newPlayerIds.length >= match.maxPlayers ? 'full' : 'open';

      transaction.update(_matchesCollection.doc(matchId), {
        'playerIds': newPlayerIds,
        if (teamId == 'A') 'teamA': newTeamArray,
        if (teamId == 'B') 'teamB': newTeamArray,
        'status': newStatus,
      });

      return true;
    });
  }

  /// Removes a player from a match and all teams.
  Future<void> leaveMatch(String matchId, String userId) async {
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(_matchesCollection.doc(matchId));
      if (!doc.exists) return;

      final match = MatchModel.fromMap(doc.data() as Map<String, dynamic>, matchId);

      final newPlayerIds = match.playerIds.where((id) => id != userId).toList();
      final newTeamA = match.teamA.where((id) => id != userId).toList();
      final newTeamB = match.teamB.where((id) => id != userId).toList();

      final newStatus = newPlayerIds.length >= match.maxPlayers ? 'full' : 'open';

      transaction.update(_matchesCollection.doc(matchId), {
        'playerIds': newPlayerIds,
        'teamA': newTeamA,
        'teamB': newTeamB,
        'status': newStatus,
      });
    });
  }

  /// Updates match status (e.g. to 'completed').
  Future<void> updateMatchStatus(String matchId, String status) async {
    await _matchesCollection.doc(matchId).update({'status': status});
  }

  /// Saves the final score for a match.
  Future<void> updateScore(String matchId, int scoreA, int scoreB) async {
    await _matchesCollection.doc(matchId).update({
      'scoreA': scoreA,
      'scoreB': scoreB,
    });
  }

  /// Deletes a match document.
  Future<void> deleteMatch(String matchId) async {
    await _matchesCollection.doc(matchId).delete();
  }

  /// Fetches matches where the user is a player.
  Stream<List<MatchModel>> userMatchesStream(String userId) {
    return _matchesCollection
        .where('playerIds', arrayContains: userId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                MatchModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Fetches matches created by the user.
  Stream<List<MatchModel>> createdMatchesStream(String userId) {
    return _matchesCollection
        .where('creatorId', isEqualTo: userId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                MatchModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}
