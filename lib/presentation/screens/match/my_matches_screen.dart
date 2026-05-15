import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/matches/match_provider.dart';
import '../../widgets/match_card.dart';
import '../../widgets/empty_state.dart';

/// Displays the user's active matches.
class MyMatchesScreen extends StatelessWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Matches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const _ArchiveScreen()),
              );
            },
            tooltip: 'Archive',
          ),
        ],
      ),
      body: Consumer2<MatchProvider, AuthProvider>(
        builder: (context, matchProvider, authProvider, _) {
          final now = DateTime.now();
          final userId = authProvider.userId;

          final joinedMatchesOnly = matchProvider.userMatches
              .where((m) => m.creatorId != userId);
          final createdMatches = matchProvider.createdMatches;

          final combined = {...joinedMatchesOnly, ...createdMatches}.toList();

          final upcoming = combined
              .where((m) => m.dateTime.isAfter(now))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

          if (upcoming.isEmpty) {
            return const EmptyState(
              icon: Icons.sports_outlined,
              title: 'No Upcoming Matches',
              subtitle: 'Join a match or create your own to see them here!',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: upcoming.length,
            itemBuilder: (context, index) {
              final match = upcoming[index];
              return MatchCard(
                match: match,
                currentUserId: userId,
                isMyMatchesView: true,
                onTap: () => context.push('/match/${match.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

/// Displays the user's archived matches.
class _ArchiveScreen extends StatelessWidget {
  const _ArchiveScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Matches'),
      ),
      body: Consumer2<MatchProvider, AuthProvider>(
        builder: (context, matchProvider, authProvider, _) {
          final now = DateTime.now();
          final userId = authProvider.userId;

          final joinedMatchesOnly = matchProvider.userMatches
              .where((m) => m.creatorId != userId);
          final createdMatches = matchProvider.createdMatches;

          final combined = {...joinedMatchesOnly, ...createdMatches}.toList();

          final archived = combined
              .where((m) => !m.dateTime.isAfter(now))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          if (archived.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No Archived Matches',
              subtitle: 'Past matches you created or joined will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: archived.length,
            itemBuilder: (context, index) {
              final match = archived[index];
              return Opacity(
                opacity: 0.72,
                child: MatchCard(
                  match: match,
                  currentUserId: userId,
                  isMyMatchesView: true,
                  onTap: () => context.push('/match/${match.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
