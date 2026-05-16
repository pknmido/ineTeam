import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/match_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/match_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/user_service.dart';
import 'matchmaking_service.dart';

/// Manages match state — listing, creation, joining, and filtering.
class MatchProvider extends ChangeNotifier {
  final MatchRepository _matchRepository;
  final MatchmakingService _matchmakingService = MatchmakingService();
  static const _uuid = Uuid();

  List<MatchModel> _matches = [];
  List<MatchModel> _userMatches = [];
  List<MatchModel> _createdMatches = [];
  String? _selectedSportFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;

  StreamSubscription<List<MatchModel>>? _matchesSub;
  StreamSubscription<List<MatchModel>>? _userMatchesSub;
  StreamSubscription<List<MatchModel>>? _createdMatchesSub;
  Timer? _reminderTimer;
  final Set<String> _remindedMatches = {};

  MatchProvider({MatchRepository? matchRepository})
      : _matchRepository = matchRepository ?? MatchRepository();

  // ─── Getters ─────────────────────────────────────────────────────────────
  List<MatchModel> get matches => _matches;
  List<MatchModel> get userMatches => _userMatches;
  List<MatchModel> get createdMatches => _createdMatches;
  String? get selectedSportFilter => _selectedSportFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Returns matches filtered by the current sport filter and search query.
  List<MatchModel> get filteredMatches {
    var filtered = List<MatchModel>.from(_matches);

    // Apply sport filter
    if (_selectedSportFilter != null) {
      filtered =
          filtered.where((m) => m.sport == _selectedSportFilter).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        return m.sport.toLowerCase().contains(query) ||
            m.location.toLowerCase().contains(query) ||
            m.creatorName.toLowerCase().contains(query) ||
            (m.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  // ─── Initialize Streams ──────────────────────────────────────────────────
  void initStreams(String userId) {
    if (_currentUserId == userId) return; // Prevent arbitrary drops on micro-auth refreshes
    
    _currentUserId = userId;
    clear(); // Immediately flush any old data

    // All matches
    _matchesSub = _matchRepository.matchesStream().listen((matches) {
      _matches = matches;
      notifyListeners();
    });

    // User's joined matches
    _userMatchesSub?.cancel();
    _userMatchesSub =
        _matchRepository.userMatchesStream(userId).listen((matches) {
      _userMatches = matches;
      notifyListeners();
    });

    // User's created matches
    _createdMatchesSub?.cancel();
    _createdMatchesSub =
        _matchRepository.createdMatchesStream(userId).listen((matches) {
      _createdMatches = matches;
      notifyListeners();
    });

    _startReminderTimer(userId);
  }

  void _startReminderTimer(String userId) {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final userService = UserService();
      final userProfile = await userService.getUserProfile(userId);
      if (userProfile == null) return;

      final prefs = userProfile.notificationPrefMinutes;
      final now = DateTime.now();

      final upcoming = [..._userMatches, ..._createdMatches]
          .where((m) => m.dateTime.isAfter(now));

      for (final match in upcoming) {
        if (_remindedMatches.contains(match.id)) continue;
        final diff = match.dateTime.difference(now).inMinutes;
        if (diff <= prefs && diff > 0) {
          _remindedMatches.add(match.id);
          await NotificationService().sendNotification(NotificationModel(
            id: const Uuid().v4(),
            userId: userId,
            title: 'Match Starting Soon',
            body: 'Your ${match.sport} match starts in $diff minutes!',
            type: 'match_reminder',
            createdAt: now,
          ));
        }
      }
    });
  }

  // ─── Create Match ────────────────────────────────────────────────────────
  Future<bool> createMatch({
    required String creatorId,
    required String creatorName,
    required String sport,
    required String location,
    required DateTime dateTime,
    required int maxPlayers,
    required String teamAName,
    required String teamBName,
    String? description,
    int? minSkill,
    int? maxSkill,
  }) async {
    _errorMessage = null;

    final now = DateTime.now();
    final upcomingCreated = _createdMatches.where((m) => m.dateTime.isAfter(now)).toList();
    if (upcomingCreated.length >= 2) {
      _errorMessage = 'You can only create up to 2 upcoming matches.';
      notifyListeners();
      return false;
    }

    final upcomingJoined = _userMatches.where((m) => m.dateTime.isAfter(now)).toList();
    final hasClash = upcomingJoined.any((m) => m.dateTime.isAtSameMomentAs(dateTime));
    if (hasClash) {
      _errorMessage = 'You already have a match scheduled at this time.';
      notifyListeners();
      return false;
    }

    try {
      final match = MatchModel(
        id: _uuid.v4(),
        creatorId: creatorId,
        creatorName: creatorName,
        sport: sport,
        location: location,
        dateTime: dateTime,
        maxPlayers: maxPlayers,
        playerIds: [creatorId], // Creator auto-joins
        teamA: [creatorId],     // Creator goes to Team A natively
        teamAName: teamAName,
        teamBName: teamBName,
        description: description,
        minSkill: minSkill,
        maxSkill: maxSkill,
        status: 'open',
        createdAt: DateTime.now(),
      );

      await _matchRepository.createMatch(match);
      return true;
    } on MatchRepositoryException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to create match.';
      notifyListeners();
      return false;
    }
  }

  // ─── Join Match ──────────────────────────────────────────────────────────
  Future<bool> joinMatch(String matchId, String userId, String teamId) async {
    _errorMessage = null;

    final now = DateTime.now();
    final upcomingJoined = _userMatches.where((m) => m.dateTime.isAfter(now) && m.creatorId != userId).toList();
    if (upcomingJoined.length >= 2) {
      _errorMessage = 'You can only join up to 2 upcoming matches.';
      notifyListeners();
      return false;
    }

    MatchModel? targetMatch;
    final allKnown = {..._matches, ..._createdMatches, ..._userMatches};
    for (final m in allKnown) {
      if (m.id == matchId) {
        targetMatch = m;
        break;
      }
    }

    if (targetMatch != null) {
      final allUpcoming = {..._createdMatches, ..._userMatches}.where((m) => m.dateTime.isAfter(now)).toList();
      final hasClash = allUpcoming.any((m) => m.dateTime.isAtSameMomentAs(targetMatch!.dateTime));
      if (hasClash) {
        _errorMessage = 'You already have a match scheduled at this time.';
        notifyListeners();
        return false;
      }
    }

    try {
      await _matchRepository.joinMatch(matchId, userId, teamId);
      return true;
    } on MatchRepositoryException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to join match.';
      notifyListeners();
      return false;
    }
  }

  // ─── Leave Match ─────────────────────────────────────────────────────────
  Future<bool> leaveMatch(String matchId, String userId) async {
    try {
      await _matchRepository.leaveMatch(matchId, userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to leave match.';
      notifyListeners();
      return false;
    }
  }

  // ─── Delete Match ────────────────────────────────────────────────────────
  Future<bool> deleteMatch(String matchId) async {
  _errorMessage = null;

  try {
    MatchModel? matchToDelete;
    final allKnown = {..._matches, ..._createdMatches, ..._userMatches};
    for (final m in allKnown) {
      if (m.id == matchId) {
        matchToDelete = m;
        break;
      }
    }

    if (matchToDelete != null) {
      final notifService = NotificationService();
      final participants = [...matchToDelete.teamA, ...matchToDelete.teamB];
      for (final p in participants) {
        if (p != matchToDelete.creatorId) {
          await notifService.sendNotification(NotificationModel(
            id: const Uuid().v4(),
            userId: p,
            title: 'Match Cancelled',
            body: 'A ${matchToDelete.sport} match you joined has been deleted by the creator.',
            type: 'match_deleted',
            createdAt: DateTime.now(),
          ));
        }
      }
    }

    await _matchRepository.deleteMatch(matchId);

    // Instant UI update
    _matches.removeWhere((m) => m.id == matchId);
    _userMatches.removeWhere((m) => m.id == matchId);
    _createdMatches.removeWhere((m) => m.id == matchId);

    notifyListeners();
    return true;
  } catch (e) {
    _errorMessage = 'Failed to delete match: $e';
    notifyListeners();
    return false;
  }
  }

  Future<bool> updateMatchStatus(String matchId, String status) async {
  _errorMessage = null;

  try {
    await _matchRepository.updateMatchStatus(matchId, status);
    return true;
  } catch (e) {
    _errorMessage = 'Failed to update match status.';
    notifyListeners();
    return false;
  }
  }

  Future<bool> updateScore(String matchId, int scoreA, int scoreB) async {
    _errorMessage = null;

    try {
      await _matchRepository.updateScore(matchId, scoreA, scoreB);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update score.';
      notifyListeners();
      return false;
    }
  }

  // ─── Filters ─────────────────────────────────────────────────────────────
  void filterBySport(String? sport) {
    _selectedSportFilter = sport;
    notifyListeners();
  }

  void searchMatches(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _selectedSportFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  // ─── Match Stream (single match) ─────────────────────────────────────────
  Stream<MatchModel?> matchStream(String matchId) =>
      _matchRepository.matchStream(matchId);

  // ─── Team Balancing ──────────────────────────────────────────────────────
  /// Access to the matchmaking service for team suggestions.
  MatchmakingService get matchmakingService => _matchmakingService;

  /// Scours old data explicitly on logout/relogin
  void clear() {
    _currentUserId = null;
    _matches = [];
    _userMatches = [];
    _createdMatches = [];
    _errorMessage = null;

    _matchesSub?.cancel();
    _userMatchesSub?.cancel();
    _createdMatchesSub?.cancel();

    _matchesSub = null;
    _userMatchesSub = null;
    _createdMatchesSub = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    _userMatchesSub?.cancel();
    _createdMatchesSub?.cancel();
    _reminderTimer?.cancel();
    super.dispose();
  }
}
