import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/matches/match_provider.dart';
import '../../../data/services/match_service.dart';

/// Screen for creating a new match.
class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _teamAController = TextEditingController(text: 'Team A');
  final _teamBController = TextEditingController(text: 'Team B');

  String _selectedSport = SportType.football.label;
  String _selectedLocation = SportType.football.availableLocations.first;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 17, minute: 30);
  int _maxPlayers = 10;
  bool _useSkillRange = false;
  RangeValues _skillRange = const RangeValues(1, 100);
  bool _isSubmitting = false;

  // Predefined times from 17:30 to 21:30
  final List<TimeOfDay> _availableTimes = [
    const TimeOfDay(hour: 17, minute: 30),
    const TimeOfDay(hour: 18, minute: 0),
    const TimeOfDay(hour: 18, minute: 30),
    const TimeOfDay(hour: 19, minute: 0),
    const TimeOfDay(hour: 19, minute: 30),
    const TimeOfDay(hour: 20, minute: 0),
    const TimeOfDay(hour: 20, minute: 30),
    const TimeOfDay(hour: 21, minute: 0),
    const TimeOfDay(hour: 21, minute: 30),
  ];

  List<TimeOfDay> _reservedTimes = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.hour > 21 || (now.hour == 21 && now.minute >= 30)) {
      _selectedDate = now.add(const Duration(days: 1));
    } else {
      _selectedDate = now;
    }
    _fetchReservedTimes();
  }

  Future<void> _fetchReservedTimes() async {
    final service = MatchService();
    final reserved = await service.getReservedTimesForDay(
        _selectedLocation, _selectedDate);
    
    if (mounted) {
      setState(() {
        _reservedTimes = reserved.map((dt) => TimeOfDay.fromDateTime(dt)).toList();
        
        // Auto-select first available time
        if (_reservedTimes.any((t) => t.hour == _selectedTime.hour && t.minute == _selectedTime.minute)) {
          for (final t in _availableTimes) {
            if (!_reservedTimes.any((rt) => rt.hour == t.hour && rt.minute == t.minute)) {
              _selectedTime = t;
              break;
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchReservedTimes();
    }
  }

  // Removed _pickTime since we now use predefined chips.

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (dateTime.isBefore(DateTime.now())) {
      Helpers.showSnackBar(context, 'Match must be in the future',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final matchProvider = context.read<MatchProvider>();

    final success = await matchProvider.createMatch(
      creatorId: auth.userId,
      creatorName: auth.userProfile?.name ?? 'Unknown',
      sport: _selectedSport,
      location: _selectedLocation,
      dateTime: dateTime,
      maxPlayers: _maxPlayers,
      teamAName: _teamAController.text.trim().isEmpty ? 'Team A' : _teamAController.text.trim(),
      teamBName: _teamBController.text.trim().isEmpty ? 'Team B' : _teamBController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      minSkill: _useSkillRange ? _skillRange.start.round() : null,
      maxSkill: _useSkillRange ? _skillRange.end.round() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Helpers.showSnackBar(context, 'Match created! 🎉');
        context.pop();
      } else {
        Helpers.showSnackBar(
          context,
          matchProvider.errorMessage ?? 'Failed to create match',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sportColor = Helpers.sportColor(_selectedSport);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Match'),
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // ── Sport Selection ──
                Text(
                  'Sport',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: SportType.values.map((sport) {
                    final isSelected = _selectedSport == sport.label;
                    final color = Helpers.sportColor(sport.label);
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Helpers.sportIcon(sport.label),
                            size: 18,
                            color: isSelected ? color : theme.colorScheme.onSurface.withAlpha(180),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sport.label,
                            style: TextStyle(
                              color: isSelected ? color : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      selectedColor: color.withAlpha(40),
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide(
                        color: isSelected ? color.withAlpha(120) : theme.colorScheme.outline.withAlpha(60),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedSport = sport.label;
                          // Reset location for this sport
                          _selectedLocation = sport.availableLocations.first;
                          _maxPlayers = sport.defaultMaxPlayers;
                        });
                        _fetchReservedTimes();
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                Text(
                  'Location',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: SportType.values
                      .firstWhere((s) => s.label == _selectedSport)
                      .availableLocations
                      .map((loc) {
                    final isSelected = _selectedLocation == loc;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(
                        loc,
                        style: TextStyle(
                          color: isSelected ? sportColor : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selectedColor: sportColor.withAlpha(40),
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide(
                        color: isSelected ? sportColor.withAlpha(120) : theme.colorScheme.outline.withAlpha(60),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedLocation = loc;
                        });
                        _fetchReservedTimes();
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

            // ── Date ──
                Text(
                  'Date & Time',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Date',
                      prefixIcon: Icon(Icons.calendar_today,
                          color: sportColor, size: 20),
                    ),
                    child: Text(
                      Helpers.formatDate(_selectedDate),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ── Time Toggles ──
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableTimes.map((time) {
                    final isSelected = _selectedTime.hour == time.hour &&
                        _selectedTime.minute == time.minute;
                    final isReserved = _reservedTimes.any(
                        (t) => t.hour == time.hour && t.minute == time.minute);

                    return ChoiceChip(
                      selected: isSelected && !isReserved,
                      label: Text(
                        time.format(context),
                        style: TextStyle(
                          decoration: isReserved
                              ? TextDecoration.lineThrough
                              : null,
                          color: isReserved
                              ? theme.colorScheme.onSurface.withAlpha(100)
                              : null,
                        ),
                      ),
                      selectedColor: sportColor.withAlpha(40),
                      backgroundColor: isReserved
                          ? theme.colorScheme.onSurface.withAlpha(10)
                          : null,
                      onSelected: isReserved
                          ? null // Disable selection if reserved
                          : (_) {
                              setState(() {
                                _selectedTime = time;
                              });
                            },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // ── Max Players Stepper ──
                Text(
                  'Format (Players)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filled(
                      onPressed: _maxPlayers > 2
                          ? () => setState(() => _maxPlayers -= 2)
                          : null,
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: sportColor.withAlpha(30),
                        foregroundColor: sportColor,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          Helpers.formatPlayersVs(_maxPlayers),
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: sportColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _maxPlayers < 30
                          ? () => setState(() => _maxPlayers += 2)
                          : null,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: sportColor.withAlpha(30),
                        foregroundColor: sportColor,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // ── Team Names ──
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _teamAController,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'Team A Name',
                          hintText: 'e.g. Red Squad',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _teamBController,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'Team B Name',
                          hintText: 'e.g. Blue Squad',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Description ──
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Any details about the match...',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Skill Range (Optional) ──
                SwitchListTile(
                  title: Text(
                    'Restrict Skill Range',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: const Text(
                    'Only allow players within a skill range',
                  ),
                  value: _useSkillRange,
                  activeThumbColor: sportColor,
                  onChanged: (val) {
                    setState(() => _useSkillRange = val);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                if (_useSkillRange) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Min: ${_skillRange.start.round()}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        'Max: ${_skillRange.end.round()}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _skillRange,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: sportColor,
                    labels: RangeLabels(
                      '${_skillRange.start.round()}',
                      '${_skillRange.end.round()}',
                    ),
                    onChanged: (val) {
                      setState(() => _skillRange = val);
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // ── Create Button ──
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleCreate,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(_isSubmitting ? 'Creating...' : 'Create Match'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sportColor,
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      );
  }
}

