import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/matches/match_provider.dart';
import '../../widgets/match_card.dart';
import '../../widgets/sport_chip.dart';
import '../../widgets/empty_state.dart';

/// Main home screen showing available matches with filters and search.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchProvider = context.watch<MatchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search matches...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (val) => matchProvider.searchMatches(val),
              )
            : Row(
                children: [
                  Icon(
                    Icons.sports,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppInfo.appName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  matchProvider.searchMatches('');
                }
              });
            },
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 4), // small gap between AppBar and chips
          // ── Sport Filter Chips ──
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // "All" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SportChip(
                    sport: 'All',
                    isSelected: matchProvider.selectedSportFilter == null,
                    onTap: () => matchProvider.filterBySport(null),
                  ),
                ),
                // Sport-specific chips
                ...SportType.values.map((sport) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SportChip(
                        sport: sport.label,
                        isSelected:
                            matchProvider.selectedSportFilter == sport.label,
                        onTap: () {
                          if (matchProvider.selectedSportFilter == sport.label) {
                            matchProvider.filterBySport(null);
                          } else {
                            matchProvider.filterBySport(sport.label);
                          }
                        },
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Match List ──
          Expanded(
            child: matchProvider.filteredMatches.isEmpty
                ? const EmptyState(
                    icon: Icons.sports_outlined,
                    title: 'No Matches Found',
                    subtitle:
                        'Be the first to create a match!\nTap the + button below.',
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      final userId = context.read<AuthProvider>().userId;
                      if (userId.isNotEmpty) {
                        context.read<MatchProvider>().initStreams(userId);
                      }
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: matchProvider.filteredMatches.length,
                      itemBuilder: (context, index) {
                        final match = matchProvider.filteredMatches[index];
                        return MatchCard(
                          match: match,
                          onTap: () => context.push('/match/${match.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),

      // ── FAB: Create Match ──
      floatingActionButton: FloatingActionButton(
        heroTag: 'createMatch',
        onPressed: () => context.push('/create-match'),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
