import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/challenges/Challenge.dart';
import '/services/challenges/Challenge_Service.dart';
import '/services/prizes/Prize.dart';
import '/services/prizes/Prize_Service.dart';
import '/services/users/User.dart';
import '/theme/terminal_theme.dart';
import '/theme/responsive.dart';
import '/services/notifications/notifications.dart';

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Challenge> _allChallenges = [];
  List<Challenge> _filteredChallenges = [];
  bool _isLoading = true;
  ChallengeType? _selectedType;
  ChallengeDifficulty? _selectedDifficulty;
  int _selectedTabIndex = 0;
  Map<String, Prize> _prizeCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadChallenges();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
        _applyFilters();
      });
    }
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    try {
      final challenges = await ChallengeService.fetchChallenges();

      // Load all unique prizes
      final prizeIds = challenges
          .map((c) => c.prize)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (prizeIds.isNotEmpty) {
        final prizes = await PrizeService.getPrizesByIds(prizeIds);
        _prizeCache = {for (var prize in prizes) prize.id: prize};
      }

      if (mounted) {
        setState(() {
          _allChallenges = challenges;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    List<Challenge> filtered = List.from(_allChallenges);
    final now = DateTime.now();

    // Apply tab filter (All/Active/Expired)
    if (_selectedTabIndex == 1) {
      // Active tab - must be active AND not expired
      filtered = filtered.where((c) {
        final isExpired = c.endDate.isBefore(now);
        return c.isActive && !isExpired;
      }).toList();
    } else if (_selectedTabIndex == 2) {
      // Expired tab - filter by end date passed
      filtered = filtered.where((c) => c.endDate.isBefore(now)).toList();
    }

    // Apply type filter
    if (_selectedType != null) {
      filtered = filtered.where((c) => c.type == _selectedType).toList();
    }

    // Apply difficulty filter
    if (_selectedDifficulty != null) {
      filtered = filtered
          .where((c) => c.difficulty == _selectedDifficulty)
          .toList();
    }

    setState(() {
      _filteredChallenges = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedDifficulty = null;
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            Icon(Symbols.mountain_flag, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Challenges',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final manager = NotificationScope.of(context);
              if (manager == null) {
                return IconButton(
                  icon: Icon(Symbols.notifications, color: colorScheme.primary),
                  onPressed: () {},
                  tooltip: 'Notifications',
                );
              }
              return NotificationBellButton(manager: manager);
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filters section
            _buildFilters(colorScheme, textTheme),
            // Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredChallenges.isEmpty
                  ? _buildEmptyState(colorScheme, textTheme)
                  : _buildChallengesList(colorScheme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ColorScheme colorScheme, TextTheme textTheme) {
    final hasActiveFilters =
        _selectedType != null || _selectedDifficulty != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.filter_list, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: Icon(Symbols.close, size: 16),
                  label: Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Type filter
              _buildFilterChip(
                label:
                    'Type: ${_selectedType?.toString().split('.').last ?? 'All'}',
                icon: Symbols.category,
                isSelected: _selectedType != null,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () => _showTypeFilterDialog(colorScheme, textTheme),
              ),
              // Difficulty filter
              _buildFilterChip(
                label:
                    'Difficulty: ${_selectedDifficulty?.toString().split('.').last ?? 'All'}',
                icon: Symbols.signal_cellular_alt,
                isSelected: _selectedDifficulty != null,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () =>
                    _showDifficultyFilterDialog(colorScheme, textTheme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilterDialog(ColorScheme colorScheme, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('All'),
              leading: Radio<ChallengeType?>(
                value: null,
                groupValue: _selectedType,
                onChanged: (value) {
                  setState(() => _selectedType = value);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
            ),
            ...ChallengeType.values.map(
              (type) => ListTile(
                title: Text(type.toString().split('.').last.toUpperCase()),
                leading: Radio<ChallengeType?>(
                  value: type,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() => _selectedType = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDifficultyFilterDialog(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Difficulty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('All'),
              leading: Radio<ChallengeDifficulty?>(
                value: null,
                groupValue: _selectedDifficulty,
                onChanged: (value) {
                  setState(() => _selectedDifficulty = value);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
            ),
            ...ChallengeDifficulty.values.map(
              (difficulty) => ListTile(
                title: Text(
                  difficulty.toString().split('.').last.toUpperCase(),
                ),
                leading: Radio<ChallengeDifficulty?>(
                  value: difficulty,
                  groupValue: _selectedDifficulty,
                  onChanged: (value) {
                    setState(() => _selectedDifficulty = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.search_off,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Challenges Found',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesList(ColorScheme colorScheme, TextTheme textTheme) {
    return ListView(
      padding: Responsive.pagePadding(context),
      children: _filteredChallenges
          .map(
            (challenge) =>
                _buildChallengeCard(challenge, colorScheme, textTheme),
          )
          .toList(),
    );
  }

  Widget _buildChallengeCard(
    Challenge challenge,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final difficultyColor = _getDifficultyColor(challenge.difficulty);
    final typeIcon = _getTypeIcon(challenge.type);
    final daysRemaining = challenge.endDate.difference(DateTime.now()).inDays;
    final isExpired = daysRemaining < 0;
    final prize = _prizeCache[challenge.prize];
    final requirementCount = challenge.requirements
        .split('\n')
        .where((req) => req.trim().isNotEmpty)
        .length;

    // Get type label
    String? typeLabel;
    switch (challenge.type) {
      case ChallengeType.special:
        typeLabel = 'SPECIAL';
        break;
      case ChallengeType.weekly:
        typeLabel = 'WEEKLY';
        break;
      case ChallengeType.monthly:
        typeLabel = 'MONTHLY';
        break;
      case ChallengeType.scratch:
        typeLabel = 'SCRATCH OSes ONLY';
        break;
      case ChallengeType.base:
        typeLabel = 'BASE OSes ONLY';
        break;
      case ChallengeType.normal:
        typeLabel = null; // No label for normal
        break;
    }

    return Card(
      color: colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: InkWell(
        onTap: () => _showChallengeDetail(challenge, colorScheme, textTheme),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: challenge.isActive && !isExpired
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: challenge.isActive && !isExpired
                      ? TerminalColors.green
                      : isExpired
                      ? TerminalColors.red
                      : colorScheme.outline,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(typeIcon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              // Title and metadata
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (challenge.isActive && !isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: TerminalColors.green.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: TerminalColors.green,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: textTheme.labelSmall?.copyWith(
                                color: TerminalColors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          )
                        else if (isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: TerminalColors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: TerminalColors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'EXPIRED',
                              style: textTheme.labelSmall?.copyWith(
                                color: TerminalColors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (typeLabel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              typeLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Icon(
                          Symbols.schedule,
                          size: 12,
                          color: daysRemaining <= 3 && !isExpired
                              ? TerminalColors.red
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isExpired
                              ? 'Ended'
                              : '$daysRemaining day${daysRemaining != 1 ? 's' : ''}',
                          style: textTheme.bodySmall?.copyWith(
                            color: daysRemaining <= 3 && !isExpired
                                ? TerminalColors.red
                                : colorScheme.onSurfaceVariant,
                            fontWeight: daysRemaining <= 3 && !isExpired
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Symbols.signal_cellular_alt,
                          size: 12,
                          color: difficultyColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          challenge.difficulty
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: textTheme.bodySmall?.copyWith(
                            color: difficultyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Symbols.checklist,
                          size: 12,
                          color: TerminalColors.cyan,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$requirementCount req${requirementCount != 1 ? 's' : ''}',
                          style: textTheme.bodySmall?.copyWith(
                            color: TerminalColors.cyan,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Prize section with image
              Container(
                width: 200,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TerminalColors.yellow.withValues(alpha: 0.2),
                      TerminalColors.yellow.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: TerminalColors.yellow.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Prize image or icon
                    if (prize?.picture != null && prize!.picture!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: TerminalColors.yellow.withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Image.network(
                            prize.picture!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: TerminalColors.yellow.withValues(
                                  alpha: 0.2,
                                ),
                                child: Icon(
                                  Symbols.emoji_events,
                                  color: TerminalColors.yellow,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: TerminalColors.yellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: TerminalColors.yellow.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Symbols.emoji_events,
                          color: TerminalColors.yellow,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 10),
                    // Prize details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            prize?.title ?? 'Prize',
                            style: textTheme.labelLarge?.copyWith(
                              color: TerminalColors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (prize != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Symbols.toll,
                                  size: 12,
                                  color: TerminalColors.yellow,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${prize.cost} coins',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: TerminalColors.yellow.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(
                                  Symbols.inventory_2,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${prize.stock} left',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return TerminalColors.green;
      case ChallengeDifficulty.medium:
        return TerminalColors.yellow;
      case ChallengeDifficulty.hard:
        return TerminalColors.red;
    }
  }

  IconData _getTypeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.special:
        return Symbols.star_rate;
      case ChallengeType.weekly:
        return Symbols.date_range;
      case ChallengeType.monthly:
        return Symbols.calendar_month;
      case ChallengeType.scratch:
        return Symbols.code;
      case ChallengeType.base:
        return Symbols.foundation;
      case ChallengeType.normal:
        return Symbols.flag;
    }
  }

  void _showChallengeDetail(
    Challenge challenge,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) async {
    // Get prize from cache or load it
    Prize? prize = _prizeCache[challenge.prize];
    if (prize == null && challenge.prize.isNotEmpty) {
      prize = await PrizeService.getPrizeById(challenge.prize);
      if (prize != null) {
        _prizeCache[challenge.prize] = prize;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ChallengeDetailDialog(
        challenge: challenge,
        prize: prize,
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
    );
  }
}

class ChallengeDetailDialog extends StatelessWidget {
  final Challenge challenge;
  final Prize? prize;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const ChallengeDetailDialog({
    super.key,
    required this.challenge,
    this.prize,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final difficultyColor = _getDifficultyColor(challenge.difficulty);
    final typeIcon = _getTypeIcon(challenge.type);
    final daysRemaining = challenge.endDate.difference(DateTime.now()).inDays;
    final isExpired = daysRemaining < 0;
    final requirements = challenge.requirements
        .split('\n')
        .where((req) => req.trim().isNotEmpty)
        .toList();

    return Dialog(
      backgroundColor: colorScheme.surfaceContainer,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        typeIcon,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.title,
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            challenge.type
                                .toString()
                                .split('.')
                                .last
                                .toUpperCase(),
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Symbols.close, color: colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Status and difficulty
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (challenge.isActive && !isExpired)
                      _buildBadge(
                        'ACTIVE',
                        TerminalColors.green,
                        Symbols.check_circle,
                      )
                    else if (isExpired)
                      _buildBadge(
                        'EXPIRED',
                        TerminalColors.red,
                        Symbols.cancel,
                      ),
                    _buildBadge(
                      challenge.difficulty
                          .toString()
                          .split('.')
                          .last
                          .toUpperCase(),
                      difficultyColor,
                      Symbols.signal_cellular_alt,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                _buildSection(
                  title: 'Description',
                  icon: Symbols.description,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      challenge.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Requirements
                _buildSection(
                  title: 'Requirements',
                  icon: Symbols.checklist,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: requirements.asMap().entries.map((entry) {
                        final index = entry.key;
                        final req = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < requirements.length - 1 ? 12 : 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colorScheme.primary,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  req,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Prize
                _buildSection(
                  title: 'Reward',
                  icon: Symbols.emoji_events,
                  child: prize != null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: TerminalColors.yellow.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: TerminalColors.yellow.withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (prize!.picture != null &&
                                      prize!.picture!.isNotEmpty)
                                    Container(
                                      width: 48,
                                      height: 48,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: TerminalColors.yellow
                                              .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(prize!.picture!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 48,
                                      height: 48,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: TerminalColors.yellow.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: TerminalColors.yellow
                                              .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Symbols.emoji_events,
                                        color: TerminalColors.yellow,
                                        size: 24,
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prize!.title,
                                          style: textTheme.titleLarge?.copyWith(
                                            color: TerminalColors.yellow,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Symbols.inventory_2,
                                              size: 16,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${prize!.stock} left',
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (prize!.description.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  prize!.description,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Symbols.error,
                                color: colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Prize information not available',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Timeline
                _buildSection(
                  title: 'Timeline',
                  icon: Symbols.schedule,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildTimelineRow(
                          'Start Date',
                          _formatDate(challenge.startDate),
                          Symbols.event_available,
                          TerminalColors.green,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                            height: 1,
                          ),
                        ),
                        _buildTimelineRow(
                          'End Date',
                          _formatDate(challenge.endDate),
                          Symbols.event_busy,
                          TerminalColors.red,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                            height: 1,
                          ),
                        ),
                        _buildTimelineRow(
                          'Time Remaining',
                          isExpired
                              ? 'Challenge Ended'
                              : '$daysRemaining day${daysRemaining != 1 ? 's' : ''}',
                          Symbols.timer,
                          isExpired
                              ? TerminalColors.red
                              : daysRemaining <= 3
                              ? TerminalColors.yellow
                              : TerminalColors.cyan,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isExpired || !challenge.isActive
                            ? null
                            : () => _handleMarkAsCompleted(context),
                        icon: Icon(Symbols.check, size: 20),
                        label: Text('Mark as Completed'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return TerminalColors.green;
      case ChallengeDifficulty.medium:
        return TerminalColors.yellow;
      case ChallengeDifficulty.hard:
        return TerminalColors.red;
    }
  }

  IconData _getTypeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.special:
        return Symbols.star_rate;
      case ChallengeType.weekly:
        return Symbols.date_range;
      case ChallengeType.monthly:
        return Symbols.calendar_month;
      case ChallengeType.scratch:
        return Symbols.code;
      case ChallengeType.base:
        return Symbols.foundation;
      case ChallengeType.normal:
        return Symbols.flag;
    }
  }

  Future<void> _handleMarkAsCompleted(BuildContext context) async {
    final currentUser = UserService.currentUser;
    if (currentUser == null) {
      GlobalNotificationService.instance.showError(
        'You need to be logged in to complete challenges.',
      );
      return;
    }

    final projectId = _extractProjectId(context);
    if (projectId != null) {
      final project = await ProjectService.getProjectById(projectId);
      if (project != null && project.owner == currentUser.id) {
        await _completeChallengeForProject(context, project);
        return;
      }
    }

    await _showProjectSelectionDialog(context, currentUser.id);
  }

  Future<void> _completeChallengeForProject(
    BuildContext context,
    Project project,
  ) async {
    try {
      await ChallengeService.markChallengeAsCompleted(
        project: project,
        challenge: challenge,
      );
      Navigator.of(context).pop();
      GlobalNotificationService.instance.showSuccess(
        '${challenge.title} marked as completed for ${project.title}.',
      );
    } catch (e) {
      GlobalNotificationService.instance.showError(
        'Failed to mark challenge as complete: $e',
      );
    }
  }

  Future<void> _showProjectSelectionDialog(
    BuildContext context,
    String userId,
  ) async {
    final projects = await ProjectService.getProjects(userId);
    if (projects.isEmpty) {
      GlobalNotificationService.instance.showError(
        'You do not have any projects yet.',
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return Dialog(
          backgroundColor: colorScheme.surfaceContainer,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.folder_open,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Select Project',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Symbols.close,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Projects list
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final project = projects[index];
                      final hours = (project.time / 3600).toStringAsFixed(1);
                      final hasImage = project.imageURL.isNotEmpty;

                      return InkWell(
                        onTap: () async {
                          Navigator.of(dialogContext).pop();
                          await _completeChallengeForProject(context, project);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Project image/thumbnail
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  color: colorScheme.surfaceContainer,
                                  child: hasImage
                                      ? Image.network(
                                          project.imageURL,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.1),
                                                  child: Icon(
                                                    Symbols.image,
                                                    color: colorScheme.primary
                                                        .withValues(alpha: 0.3),
                                                    size: 28,
                                                  ),
                                                );
                                              },
                                        )
                                      : Container(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          child: Icon(
                                            Symbols.image,
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.3),
                                            size: 28,
                                          ),
                                        ),
                                ),
                              ),
                              // Project info
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        project.title,
                                        style: textTheme.titleSmall?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Symbols.schedule,
                                            size: 13,
                                            color: TerminalColors.cyan,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${hours}h',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: TerminalColors.cyan,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Symbols.flag,
                                            size: 13,
                                            color: TerminalColors.yellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            project.level,
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: TerminalColors.yellow,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                ),
                                          ),
                                          if (project.likes > 0) ...[
                                            const SizedBox(width: 12),
                                            Icon(
                                              Symbols.favorite,
                                              size: 13,
                                              color: TerminalColors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${project.likes}',
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: TerminalColors.red,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Arrow indicator
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  Symbols.chevron_right,
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int? _extractProjectId(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    if (routeName == null) return null;

    final match = RegExp(r'/projects/(\d+)').firstMatch(routeName);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    return null;
  }
}
