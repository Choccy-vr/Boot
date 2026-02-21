import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/services/prizes/Prize.dart';
import '/services/prizes/Prize_Service.dart';
import '/services/challenges/Challenge.dart';
import '/services/challenges/Challenge_Service.dart';
import '/services/supabase/DB/supabase_db.dart';
import '/services/Storage/storage.dart';
import '/services/misc/logger.dart';
import '/services/notifications/notifications.dart';
import '/theme/terminal_theme.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedTab = 0;
  List<Prize> _prizes = [];
  List<Challenge> _challenges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prizes = await PrizeService.fetchPrizes();
      final challenges = await ChallengeService.fetchChallenges();
      setState(() {
        _prizes = prizes;
        _challenges = challenges;
      });
    } catch (e) {
      AppLogger.error('Failed to load admin data', e);
    } finally {
      setState(() => _isLoading = false);
    }
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
        ),
        title: Row(
          children: [
            Icon(
              Symbols.admin_panel_settings,
              color: TerminalColors.cyan,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Admin Panel',
              style: textTheme.titleLarge?.copyWith(
                color: TerminalColors.cyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Symbols.refresh, color: colorScheme.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border(right: BorderSide(color: colorScheme.outline)),
            ),
            child: Column(
              children: [
                _buildTabButton(
                  icon: Symbols.redeem,
                  label: 'Prizes',
                  index: 0,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                _buildTabButton(
                  icon: Symbols.emoji_events,
                  label: 'Bounties',
                  index: 1,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : _selectedTab == 0
                ? _buildPrizesPanel()
                : _buildChallengesPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required int index,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: textTheme.bodyLarge?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizesPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colorScheme.outline)),
          ),
          child: Row(
            children: [
              Text(
                'Manage Prizes',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showPrizeDialog(),
                icon: const Icon(Symbols.add),
                label: const Text('Create Prize'),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _prizes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.redeem,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No prizes yet',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prizes.length,
                  itemBuilder: (context, index) {
                    final prize = _prizes[index];
                    return _buildPrizeCard(prize, colorScheme, textTheme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPrizeCard(
    Prize prize,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colorScheme.outline),
            ),
            child: prize.picture != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      prize.picture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Symbols.image, color: colorScheme.outline),
                    ),
                  )
                : Icon(Symbols.redeem, color: colorScheme.outline),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prize.title,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prize.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Symbols.paid, size: 16, color: TerminalColors.yellow),
                    const SizedBox(width: 4),
                    Text(
                      '${prize.cost} coins',
                      style: textTheme.bodySmall?.copyWith(
                        color: TerminalColors.yellow,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Symbols.inventory_2,
                      size: 16,
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stock: ${prize.stock}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Edit button
          IconButton(
            onPressed: () => _showPrizeDialog(prize: prize),
            icon: Icon(Symbols.edit, color: colorScheme.primary, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: colorScheme.outline),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
          IconButton(
            onPressed: () => _showDeletePrizeDialog(prize),
            icon: Icon(Symbols.delete, color: TerminalColors.red, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: TerminalColors.red.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colorScheme.outline)),
          ),
          child: Row(
            children: [
              Text(
                'Manage Bounties',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateChallengeDialog(),
                icon: const Icon(Symbols.add),
                label: const Text('Create Bounty'),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _challenges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.emoji_events,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Bounties yet',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _challenges.length,
                  itemBuilder: (context, index) {
                    final challenge = _challenges[index];
                    return _buildChallengeCard(
                      challenge,
                      colorScheme,
                      textTheme,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(
    Challenge challenge,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final difficultyColor = challenge.difficulty == ChallengeDifficulty.easy
        ? TerminalColors.green
        : challenge.difficulty == ChallengeDifficulty.medium
        ? TerminalColors.yellow
        : TerminalColors.red;
    Prize? rewardPrize;
    for (final prize in _prizes) {
      if (prize.type == PrizeType.reward && prize.key == challenge.key) {
        rewardPrize = prize;
        break;
      }
    }
    final rewardLabel = rewardPrize != null
        ? 'Reward: ${rewardPrize.title}'
        : '${challenge.coins} coins';
    final rewardIcon = rewardPrize != null ? Symbols.redeem : Symbols.toll;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: challenge.isActive
                      ? TerminalColors.green.withOpacity(0.1)
                      : colorScheme.outline.withOpacity(0.1),
                  border: Border.all(
                    color: challenge.isActive
                        ? TerminalColors.green
                        : colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  challenge.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: textTheme.labelSmall?.copyWith(
                    color: challenge.isActive
                        ? TerminalColors.green
                        : colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.description,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildChip(
                icon: Symbols.category,
                label: challenge.type.toString().split('.').last.toUpperCase(),
                color: colorScheme.secondary,
                textTheme: textTheme,
              ),
              _buildChip(
                icon: Symbols.flag,
                label: challenge.difficulty.toString().split('.').last,
                color: difficultyColor,
                textTheme: textTheme,
              ),
              _buildChip(
                icon: Symbols.calendar_month,
                label:
                    '${challenge.startDate.month}/${challenge.startDate.day} - ${challenge.endDate.month}/${challenge.endDate.day}',
                color: colorScheme.tertiary,
                textTheme: textTheme,
              ),
              _buildChip(
                icon: rewardIcon,
                label: rewardLabel,
                color: TerminalColors.yellow,
                textTheme: textTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _showEditChallengeDialog(challenge),
                icon: Icon(Symbols.edit, color: colorScheme.primary, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showDeleteChallengeDialog(challenge),
                icon: Icon(Symbols.delete, color: TerminalColors.red, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(
                      color: TerminalColors.red.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required TextTheme textTheme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }

  void _showPrizeDialog({Prize? prize}) {
    final TextEditingController titleController;
    final TextEditingController descriptionController;
    final TextEditingController costController;
    final TextEditingController stockController;
    final TextEditingController multiplierController;
    final TextEditingController coinsController;
    final TextEditingController keyController;
    final TextEditingController specsController;
    String? imageUrl;
    PrizeType selectedType;
    Set<PrizeCountries> selectedCountries;
    bool customGrant;
    bool isEditing;
    List<Map<String, dynamic>> prizeOptions = [];
    List<Map<String, dynamic>> prizeOptionValues = [];

    if (prize == null) {
      titleController = TextEditingController();
      descriptionController = TextEditingController();
      costController = TextEditingController();
      stockController = TextEditingController();
      multiplierController = TextEditingController(text: '0');
      coinsController = TextEditingController(text: '0');
      keyController = TextEditingController();
      specsController = TextEditingController();
      imageUrl = null;
      selectedType = PrizeType.normal;
      selectedCountries = {PrizeCountries.all};
      customGrant = true;
      isEditing = false;
    } else {
      titleController = TextEditingController(text: prize.title);
      descriptionController = TextEditingController(text: prize.description);
      costController = TextEditingController(text: prize.cost.toString());
      stockController = TextEditingController(text: prize.stock.toString());
      multiplierController = TextEditingController(
        text: prize.multiplier.toString(),
      );
      coinsController = TextEditingController(text: prize.coins.toString());
      keyController = TextEditingController(text: prize.key);
      specsController = TextEditingController(text: prize.specs);
      imageUrl = prize.picture;
      selectedType = prize.type;
      selectedCountries = prize.countries.toSet();
      customGrant = prize.customGrant;
      isEditing = true;
    }

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Add listeners to update preview
            void updatePreview() => setDialogState(() {});

            titleController.addListener(updatePreview);
            descriptionController.addListener(updatePreview);
            costController.addListener(updatePreview);
            stockController.addListener(updatePreview);
            multiplierController.addListener(updatePreview);
            coinsController.addListener(updatePreview);
            keyController.addListener(updatePreview);
            specsController.addListener(updatePreview);

            // Create preview prize
            final previewPrize = Prize(
              id: 'preview',
              createdAt: DateTime.now(),
              title: titleController.text.isEmpty
                  ? 'Prize Title'
                  : titleController.text,
              description: descriptionController.text.isEmpty
                  ? 'Prize description will appear here...'
                  : descriptionController.text,
              picture: imageUrl,
              cost: int.tryParse(costController.text) ?? 0,
              stock: int.tryParse(stockController.text) ?? 0,
              multiplier: double.tryParse(multiplierController.text) ?? 0,
              key: keyController.text,
              coins: int.tryParse(coinsController.text) ?? 0,
              type: selectedType,
              countries: selectedCountries.toList(),
              specs: specsController.text,
              customGrant: customGrant,
            );

            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colorScheme.outline),
              ),
              title: Row(
                children: [
                  Icon(Symbols.redeem, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  if (isEditing) ...[
                    Text(
                      'Edit Prize',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Create New Prize',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 900,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Section
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              controller: titleController,
                              label: 'Title',
                              icon: Symbols.title,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: descriptionController,
                              label: 'Description',
                              icon: Symbols.description,
                              maxLines: 3,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: stockController,
                                    label: 'Stock',
                                    icon: Symbols.inventory_2,
                                    keyboardType: TextInputType.number,
                                    colorScheme: colorScheme,
                                    textTheme: textTheme,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDropdown<PrizeType>(
                              label: 'Prize Type',
                              value: selectedType,
                              items: PrizeType.values,
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedType = value;
                                    if (selectedType == PrizeType.reward) {
                                      costController.text = '0';
                                    }
                                  });
                                }
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                            const SizedBox(height: 16),
                            if (selectedType != PrizeType.reward) ...[
                              if (customGrant) ...[
                                _buildTextField(
                                  controller: costController,
                                  label: 'Cost Per Dollar',
                                  icon: Symbols.paid,
                                  keyboardType: TextInputType.number,
                                  colorScheme: colorScheme,
                                  textTheme: textTheme,
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                _buildTextField(
                                  controller: costController,
                                  label: 'Cost (coins)',
                                  icon: Symbols.paid,
                                  keyboardType: TextInputType.number,
                                  colorScheme: colorScheme,
                                  textTheme: textTheme,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                            // Conditional fields based on type
                            if (selectedType == PrizeType.keyed ||
                                selectedType == PrizeType.reward) ...[
                              _buildTextField(
                                controller: keyController,
                                label: selectedType == PrizeType.keyed
                                    ? 'Required Key (required)'
                                    : 'Key (optional)',
                                icon: Symbols.key,
                                colorScheme: colorScheme,
                                textTheme: textTheme,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (selectedType == PrizeType.reward) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: coinsController,
                                      label: 'Coin Reward',
                                      icon: Symbols.toll,
                                      keyboardType: TextInputType.number,
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: multiplierController,
                                      label: 'Multiplier',
                                      icon: Symbols.percent,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Specs field (optional, tall text box)
                            _buildTextField(
                              controller: specsController,
                              label: 'Specs (optional)',
                              icon: Symbols.notes,
                              maxLines: 5,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                            const SizedBox(height: 16),
                            // Prize Options & Values (only for normal and keyed types)
                            if (selectedType == PrizeType.normal ||
                                selectedType == PrizeType.keyed) ...[
                              _buildPrizeOptionsSection(
                                prizeOptions: prizeOptions,
                                prizeOptionValues: prizeOptionValues,
                                prizeId: prize?.id ?? '',
                                onChanged: () => setDialogState(() {}),
                                colorScheme: colorScheme,
                                textTheme: textTheme,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Custom Grant checkbox (only for grant type)
                            if (selectedType == PrizeType.grant) ...[
                              CheckboxListTile(
                                value: customGrant,
                                onChanged: (value) {
                                  setDialogState(() {
                                    customGrant = value ?? true;
                                  });
                                },
                                title: Text(
                                  'Custom Grant',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Countries selector
                            _buildCountriesSelector(
                              selectedCountries: selectedCountries,
                              onChanged: (countries) {
                                setDialogState(() {
                                  selectedCountries = countries;
                                });
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final url =
                                      await StorageService.uploadFileWithPicker(
                                        path:
                                            'prizes/${DateTime.now().millisecondsSinceEpoch}',
                                      );
                                  if (url != 'User cancelled') {
                                    final publicUrl =
                                        await StorageService.getPublicUrl(
                                          path: url,
                                        );
                                    setDialogState(() => imageUrl = publicUrl);
                                  }
                                } catch (e) {
                                  AppLogger.error('Failed to upload image', e);
                                }
                              },
                              icon: Icon(Symbols.upload),
                              label: Text(
                                imageUrl == null
                                    ? 'Upload Image'
                                    : 'Image Uploaded',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: imageUrl == null
                                    ? colorScheme.primary
                                    : TerminalColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Preview Section
                      SizedBox(
                        width: 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 520,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildShopPrizeCard(
                                  previewPrize,
                                  colorScheme,
                                  textTheme,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validation
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        stockController.text.isEmpty ||
                        imageUrl == null) {
                      GlobalNotificationService.instance.showError(
                        'Please fill all required fields and upload an image',
                      );
                      return;
                    }

                    if (selectedType != PrizeType.reward &&
                        costController.text.isEmpty) {
                      GlobalNotificationService.instance.showError(
                        'Please enter a cost for this prize',
                      );
                      return;
                    }

                    // Check if keyed type requires a key
                    if (selectedType == PrizeType.keyed &&
                        keyController.text.isEmpty) {
                      GlobalNotificationService.instance.showError(
                        'Keyed prizes must have a key specified',
                      );
                      return;
                    }

                    try {
                      await _handlePrizeAction(
                        title: titleController.text,
                        description: descriptionController.text,
                        cost: int.tryParse(costController.text) ?? 0,
                        stock: int.tryParse(stockController.text) ?? 0,
                        imageUrl: imageUrl!,
                        type: selectedType,
                        isEditing: isEditing,
                        prizeId: prize?.id ?? '',
                        key: keyController.text,
                        coins: int.tryParse(coinsController.text) ?? 0,
                        multiplier:
                            double.tryParse(multiplierController.text) ?? 0,
                        countries: selectedCountries.toList(),
                        specs: specsController.text,
                        customGrant: customGrant,
                        options: prizeOptions
                            .map((o) => PrizeOption(
                                  id: o['id'] ?? '',
                                  createdAt: o['createdAt'] ?? DateTime.now(),
                                  prizeId: prize?.id ?? '',
                                  name: o['name'] ?? '',
                                ))
                            .toList(),
                        optionValues: prizeOptionValues
                            .map((v) => PrizeOptionValues(
                                  id: v['id'] ?? '',
                                  createdAt: v['createdAt'] ?? DateTime.now(),
                                  optionId: v['optionId'] ?? '',
                                  label: v['label'] ?? '',
                                  priceModifier: v['priceModifier'] ?? 0,
                                  stock: v['stock'] ?? 0,
                                ))
                            .toList(),
                      );
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      AppLogger.error('Failed to create/edit prize', e);
                      GlobalNotificationService.instance.showError(
                        'Failed to create/edit prize',
                      );
                    }
                  },
                  child: isEditing
                      ? const Text('Update')
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePrizeAction({
    required String title,
    required String description,
    required int cost,
    required int stock,
    required String imageUrl,
    required PrizeType type,
    required bool isEditing,
    String prizeId = '',
    String key = '',
    int coins = 0,
    double multiplier = 0,
    List<PrizeCountries> countries = const [PrizeCountries.all],
    String specs = '',
    bool customGrant = false,
    List<PrizeOption> options = const [],
    List<PrizeOptionValues> optionValues = const [],
  }) async {
    if (!isEditing) {
      await SupabaseDB.upsertData(
        table: 'prizes',
        data: {
          'title': title,
          'description': description,
          'cost': cost,
          'stock': stock,
          'picture': imageUrl,
          'type': imageUrl.toString().split('.').last,
          'key': key == '' ? null : key,
          'coins': coins,
          'multiplier': multiplier,
          'countries': countries
              .map((c) => c.toString().split('.').last)
              .toList(),
          'specs': specs,
          'custom_grant': customGrant,
        },
      );
      if(options.isNotEmpty){
      await SupabaseDB.upsertData(
        table: 'prize_options',
        bulkData: options
            .map((option) => option.toJson())
            .toList(),
      );
      }
      if(optionValues.isNotEmpty){
        await SupabaseDB.upsertData(
          table: 'prize_option_values',
          bulkData: optionValues
              .map((optionValue) => optionValue.toJson())
              .toList(),
        );
      }
    } else {
      if (prizeId.isEmpty) {
        GlobalNotificationService.instance.showError(
          'Invalid prize ID for editing',
        );
        return;
      }
      await SupabaseDB.updateData(
        table: 'prizes',
        data: {
          'title': title,
          'description': description,
          'cost': cost,
          'stock': stock,
          'picture': imageUrl,
          'type': type.toString().split('.').last,
          'key': key == '' ? null : key,
          'coins': coins,
          'multiplier': multiplier,
          'countries': countries
              .map((c) => c.toString().split('.').last)
              .toList(),
          'specs': specs,
          'custom_grant': customGrant,
        },
        column: 'id',
        value: prizeId,
      );
      if (options.isNotEmpty) {
        await SupabaseDB.updateBulkData(
          table: 'prize_options',
          bulkData: options.map((option) => option.toJson()).toList(),
          onConflict: 'id',
        );
      }
      if (optionValues.isNotEmpty) {
        await SupabaseDB.updateBulkData(
          table: 'prize_option_values',
          bulkData: optionValues
              .map((optionValue) => optionValue.toJson())
              .toList(),
          onConflict: 'id',
        );
      }
    }
  }

  void _showDeletePrizeDialog(Prize prize) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: TerminalColors.red.withValues(alpha: 0.5)),
          ),
          title: Row(
            children: [
              Icon(Symbols.warning, color: TerminalColors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delete Prize',
                style: textTheme.titleLarge?.copyWith(
                  color: TerminalColors.red,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this prize?',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(
                  children: [
                    if (prize.picture != null && prize.picture!.isNotEmpty)
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            prize.picture!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Symbols.image, color: colorScheme.outline),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prize.title,
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${prize.cost} coins • ${prize.stock} in stock',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: textTheme.bodySmall?.copyWith(
                  color: TerminalColors.red.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseDB.deleteData(
                    table: 'prizes',
                    column: 'id',
                    value: prize.id,
                  );
                  GlobalNotificationService.instance.showSuccess(
                    'Prize deleted successfully!',
                  );
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  AppLogger.error('Failed to delete prize', e);
                  GlobalNotificationService.instance.showError(
                    'Failed to delete prize',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TerminalColors.red,
                foregroundColor: TerminalColors.black,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateChallengeDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final requirementsController = TextEditingController();
    final coinsController = TextEditingController(text: '0');
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    ChallengeType selectedType = ChallengeType.normal;
    ChallengeDifficulty selectedDifficulty = ChallengeDifficulty.medium;
    bool isActive = true;
    bool useRewardPrize = false;
    Prize? selectedRewardPrize;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colorScheme.outline),
              ),
              title: Row(
                children: [
                  Icon(
                    Symbols.emoji_events,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Create New Bounty',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: titleController,
                        label: 'Title',
                        icon: Symbols.title,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: descriptionController,
                        label: 'Description',
                        icon: Symbols.description,
                        maxLines: 3,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: requirementsController,
                        label: 'Requirements',
                        icon: Symbols.checklist,
                        maxLines: 2,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      // Reward Type Selection
                      Row(
                        children: [
                          Icon(
                            Symbols.redeem,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reward Type',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Coins'),
                                icon: Icon(Symbols.toll, size: 16),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Reward Prize'),
                                icon: Icon(Symbols.redeem, size: 16),
                              ),
                            ],
                            selected: {useRewardPrize},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setDialogState(() {
                                useRewardPrize = newSelection.first;
                                if (useRewardPrize) {
                                  coinsController.text = '0';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Conditional reward input
                      if (!useRewardPrize)
                        _buildTextField(
                          controller: coinsController,
                          label: 'Coins Reward',
                          icon: Symbols.toll,
                          keyboardType: TextInputType.number,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reward Prize',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedRewardPrize != null)
                              Container(
                                height: 220,
                                child: _buildShopPrizeCard(
                                  selectedRewardPrize!,
                                  colorScheme,
                                  textTheme,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Symbols.redeem,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Select a reward prize to attach to this bounty',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked =
                                    await _showSelectRewardPrizeDialog(
                                      selectedRewardPrize,
                                    );
                                if (picked != null) {
                                  setDialogState(
                                    () => selectedRewardPrize = picked,
                                  );
                                }
                              },
                              icon: const Icon(Symbols.search),
                              label: const Text('Select Reward Prize'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // Type Dropdown
                      _buildDropdown<ChallengeType>(
                        label: 'Type',
                        value: selectedType,
                        items: ChallengeType.values,
                        onChanged: (value) =>
                            setDialogState(() => selectedType = value!),
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      // Difficulty Dropdown
                      _buildDropdown<ChallengeDifficulty>(
                        label: 'Difficulty',
                        value: selectedDifficulty,
                        items: ChallengeDifficulty.values,
                        onChanged: (value) =>
                            setDialogState(() => selectedDifficulty = value!),
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              label: 'Start Date',
                              date: startDate,
                              onTap: () async {
                                final firstDate =
                                    startDate.isBefore(DateTime.now())
                                    ? startDate
                                    : DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: firstDate,
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => startDate = picked);
                                }
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePicker(
                              label: 'End Date',
                              date: endDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => endDate = picked);
                                }
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Active toggle
                      Row(
                        children: [
                          Icon(
                            Symbols.power_settings_new,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: isActive,
                            onChanged: (value) =>
                                setDialogState(() => isActive = value),
                            activeColor: TerminalColors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        requirementsController.text.isEmpty) {
                      GlobalNotificationService.instance.showError(
                        'Please fill all required fields',
                      );
                      return;
                    }

                    if (!useRewardPrize &&
                        (int.tryParse(coinsController.text) ?? 0) <= 0) {
                      GlobalNotificationService.instance.showError(
                        'Please enter a valid coin amount',
                      );
                      return;
                    }

                    if (useRewardPrize && selectedRewardPrize == null) {
                      GlobalNotificationService.instance.showError(
                        'Please select a reward prize',
                      );
                      return;
                    }

                    try {
                      await SupabaseDB.upsertData(
                        table: 'challenges',
                        data: {
                          'title': titleController.text,
                          'description': descriptionController.text,
                          'requirements': requirementsController.text,
                          'coins': useRewardPrize
                              ? 0
                              : (int.tryParse(coinsController.text) ?? 0),
                          'key': useRewardPrize
                              ? (selectedRewardPrize?.key ?? '')
                              : '',
                          'type': selectedType.toString().split('.').last,
                          'difficulty': selectedDifficulty
                              .toString()
                              .split('.')
                              .last,
                          'start_date': startDate.toIso8601String(),
                          'end_date': endDate.toIso8601String(),
                          'active': isActive,
                        },
                      );
                      GlobalNotificationService.instance.showSuccess(
                        'Bounty created successfully!',
                      );
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      AppLogger.error('Failed to create Bounty', e);
                      GlobalNotificationService.instance.showError(
                        'Failed to create Bounty',
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Prize?> _showSelectRewardPrizeDialog(Prize? selectedPrize) {
    final rewardPrizes = _prizes
        .where((prize) => prize.type == PrizeType.reward)
        .toList();

    return showDialog<Prize>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outline),
          ),
          title: Row(
            children: [
              Icon(Symbols.redeem, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Select Reward Prize',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 900,
            height: 520,
            child: rewardPrizes.isEmpty
                ? Center(
                    child: Text(
                      'No reward prizes available. Create a prize with type "reward" first.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : GridView.builder(
                    itemCount: rewardPrizes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemBuilder: (context, index) {
                      final prize = rewardPrizes[index];
                      final isSelected =
                          selectedPrize != null && selectedPrize.id == prize.id;
                      return InkWell(
                        onTap: () => Navigator.pop(context, prize),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline.withValues(alpha: 0.4),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: _buildShopPrizeCard(
                            prize,
                            colorScheme,
                            textTheme,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showEditChallengeDialog(Challenge challenge) {
    final titleController = TextEditingController(text: challenge.title);
    final descriptionController = TextEditingController(
      text: challenge.description,
    );
    final requirementsController = TextEditingController(
      text: challenge.requirements,
    );
    final coinsController = TextEditingController(
      text: challenge.coins.toString(),
    );
    DateTime startDate = challenge.startDate;
    DateTime endDate = challenge.endDate;
    ChallengeType selectedType = challenge.type;
    ChallengeDifficulty selectedDifficulty = challenge.difficulty;
    bool isActive = challenge.isActive;
    Prize? selectedRewardPrize;
    bool useRewardPrize = false;

    for (final prize in _prizes) {
      if (prize.type == PrizeType.reward && prize.key == challenge.key) {
        selectedRewardPrize = prize;
        useRewardPrize = true;
        break;
      }
    }
    if (challenge.key.isNotEmpty && selectedRewardPrize == null) {
      useRewardPrize = true;
    }

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colorScheme.outline),
              ),
              title: Row(
                children: [
                  Icon(Symbols.edit, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Bounty',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: titleController,
                        label: 'Title',
                        icon: Symbols.title,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: descriptionController,
                        label: 'Description',
                        icon: Symbols.description,
                        maxLines: 3,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: requirementsController,
                        label: 'Requirements',
                        icon: Symbols.checklist,
                        maxLines: 2,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Symbols.redeem,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reward Type',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Coins'),
                                icon: Icon(Symbols.toll, size: 16),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Reward Prize'),
                                icon: Icon(Symbols.redeem, size: 16),
                              ),
                            ],
                            selected: {useRewardPrize},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setDialogState(() {
                                useRewardPrize = newSelection.first;
                                if (useRewardPrize) {
                                  coinsController.text = '0';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!useRewardPrize)
                        _buildTextField(
                          controller: coinsController,
                          label: 'Coins Reward',
                          icon: Symbols.toll,
                          keyboardType: TextInputType.number,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reward Prize',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedRewardPrize != null)
                              Container(
                                height: 220,
                                child: _buildShopPrizeCard(
                                  selectedRewardPrize!,
                                  colorScheme,
                                  textTheme,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Symbols.redeem,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Select a reward prize to attach to this bounty',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked =
                                    await _showSelectRewardPrizeDialog(
                                      selectedRewardPrize,
                                    );
                                if (picked != null) {
                                  setDialogState(
                                    () => selectedRewardPrize = picked,
                                  );
                                }
                              },
                              icon: const Icon(Symbols.search),
                              label: const Text('Select Reward Prize'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      _buildDropdown<ChallengeType>(
                        label: 'Type',
                        value: selectedType,
                        items: ChallengeType.values,
                        onChanged: (value) =>
                            setDialogState(() => selectedType = value!),
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<ChallengeDifficulty>(
                        label: 'Difficulty',
                        value: selectedDifficulty,
                        items: ChallengeDifficulty.values,
                        onChanged: (value) =>
                            setDialogState(() => selectedDifficulty = value!),
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              label: 'Start Date',
                              date: startDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => startDate = picked);
                                }
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePicker(
                              label: 'End Date',
                              date: endDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => endDate = picked);
                                }
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Symbols.power_settings_new,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: isActive,
                            onChanged: (value) =>
                                setDialogState(() => isActive = value),
                            activeColor: TerminalColors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        requirementsController.text.isEmpty) {
                      GlobalNotificationService.instance.showError(
                        'Please fill all required fields',
                      );
                      return;
                    }

                    if (!useRewardPrize &&
                        (int.tryParse(coinsController.text) ?? 0) <= 0) {
                      GlobalNotificationService.instance.showError(
                        'Please enter a valid coin amount',
                      );
                      return;
                    }

                    if (useRewardPrize && selectedRewardPrize == null) {
                      GlobalNotificationService.instance.showError(
                        'Please select a reward prize',
                      );
                      return;
                    }

                    try {
                      await SupabaseDB.updateData(
                        table: 'challenges',
                        column: 'id',
                        value: challenge.id,
                        data: {
                          'title': titleController.text,
                          'description': descriptionController.text,
                          'requirements': requirementsController.text,
                          'coins': useRewardPrize
                              ? 0
                              : (int.tryParse(coinsController.text) ?? 0),
                          'key': useRewardPrize
                              ? (selectedRewardPrize?.key ?? '')
                              : '',
                          'type': selectedType.toString().split('.').last,
                          'difficulty': selectedDifficulty
                              .toString()
                              .split('.')
                              .last,
                          'start_date': startDate.toIso8601String(),
                          'end_date': endDate.toIso8601String(),
                          'active': isActive,
                        },
                      );
                      GlobalNotificationService.instance.showSuccess(
                        'Bounty updated successfully!',
                      );
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      AppLogger.error('Failed to update Bounty', e);
                      GlobalNotificationService.instance.showError(
                        'Failed to update Bounty',
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteChallengeDialog(Challenge challenge) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: TerminalColors.red.withValues(alpha: 0.5)),
          ),
          title: Row(
            children: [
              Icon(Symbols.warning, color: TerminalColors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delete Bounty',
                style: textTheme.titleLarge?.copyWith(
                  color: TerminalColors.red,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${challenge.title}"? This cannot be undone.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseDB.deleteData(
                    table: 'challenges',
                    column: 'id',
                    value: challenge.id,
                  );
                  GlobalNotificationService.instance.showSuccess(
                    'Bounty deleted successfully!',
                  );
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  AppLogger.error('Failed to delete Bounty', e);
                  GlobalNotificationService.instance.showError(
                    'Failed to delete Bounty',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TerminalColors.red,
                foregroundColor: TerminalColors.black,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary, size: 20),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorScheme.outline),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: colorScheme.surface,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString().split('.').last),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Symbols.calendar_month,
                  color: colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.month}/${date.day}/${date.year}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopPrizeCard(
    Prize prize,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final bool isOutOfStock = prize.stock <= 0;
    final bool isLowStock = prize.stock > 0 && prize.stock <= 5;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Stack(
                children: [
                  // Prize image
                  if (prize.picture != null && prize.picture!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        topRight: Radius.circular(11),
                      ),
                      child: Image.network(
                        prize.picture!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Symbols.redeem,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Symbols.redeem,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                    ),

                  // Stock badge
                  if (isOutOfStock || isLowStock)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? TerminalColors.red.withValues(alpha: 0.9)
                              : TerminalColors.yellow.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOutOfStock
                                ? TerminalColors.red
                                : TerminalColors.yellow,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isOutOfStock ? 'OUT OF STOCK' : 'LOW STOCK',
                          style: textTheme.labelSmall?.copyWith(
                            color: TerminalColors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    prize.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Expanded(
                    child: Text(
                      prize.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price and stock info
                  Row(
                    children: [
                      // Price
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: TerminalColors.yellow.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: TerminalColors.yellow.withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Symbols.toll,
                                size: 18,
                                color: TerminalColors.yellow,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${prize.cost}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: TerminalColors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stock count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Symbols.inventory_2,
                              size: 16,
                              color: colorScheme.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${prize.stock}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountriesSelector({
    required Set<PrizeCountries> selectedCountries,
    required Function(Set<PrizeCountries>) onChanged,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final searchController = TextEditingController();
    String searchQuery = '';

    // Define regions with their countries
    final Map<String, List<PrizeCountries>> regions = {
      'All Countries': [PrizeCountries.all],
      'North America': [
        PrizeCountries.us,
        PrizeCountries.ca,
        PrizeCountries.mx,
      ],
      'South America': [
        PrizeCountries.ar,
        PrizeCountries.br,
        PrizeCountries.cl,
        PrizeCountries.co,
        PrizeCountries.pe,
        PrizeCountries.ve,
        PrizeCountries.ec,
        PrizeCountries.bo,
        PrizeCountries.py,
        PrizeCountries.uy,
      ],
      'Europe': [
        PrizeCountries.gb,
        PrizeCountries.de,
        PrizeCountries.fr,
        PrizeCountries.it,
        PrizeCountries.es,
        PrizeCountries.nl,
        PrizeCountries.be,
        PrizeCountries.ch,
        PrizeCountries.at,
        PrizeCountries.se,
        PrizeCountries.no,
        PrizeCountries.dk,
        PrizeCountries.fi,
        PrizeCountries.ie,
        PrizeCountries.pt,
        PrizeCountries.pl,
        PrizeCountries.cz,
        PrizeCountries.gr,
        PrizeCountries.ro,
        PrizeCountries.hu,
      ],
      'Asia': [
        PrizeCountries.cn,
        PrizeCountries.jp,
        PrizeCountries.kr,
        PrizeCountries.ind,
        PrizeCountries.sg,
        PrizeCountries.my,
        PrizeCountries.th,
        PrizeCountries.vn,
        PrizeCountries.ph,
        PrizeCountries.id,
        PrizeCountries.tw,
        PrizeCountries.hk,
      ],
      'Oceania': [PrizeCountries.au, PrizeCountries.nz],
      'Middle East': [
        PrizeCountries.ae,
        PrizeCountries.sa,
        PrizeCountries.il,
        PrizeCountries.tr,
      ],
      'Africa': [
        PrizeCountries.za,
        PrizeCountries.ng,
        PrizeCountries.eg,
        PrizeCountries.ke,
        PrizeCountries.ma,
      ],
    };

    // Country name mapping
    final Map<PrizeCountries, String> countryNames = {
      PrizeCountries.all: 'All Countries',
      PrizeCountries.us: 'United States',
      PrizeCountries.ca: 'Canada',
      PrizeCountries.mx: 'Mexico',
      PrizeCountries.ar: 'Argentina',
      PrizeCountries.br: 'Brazil',
      PrizeCountries.cl: 'Chile',
      PrizeCountries.co: 'Colombia',
      PrizeCountries.pe: 'Peru',
      PrizeCountries.ve: 'Venezuela',
      PrizeCountries.ec: 'Ecuador',
      PrizeCountries.bo: 'Bolivia',
      PrizeCountries.py: 'Paraguay',
      PrizeCountries.uy: 'Uruguay',
      PrizeCountries.gb: 'United Kingdom',
      PrizeCountries.de: 'Germany',
      PrizeCountries.fr: 'France',
      PrizeCountries.it: 'Italy',
      PrizeCountries.es: 'Spain',
      PrizeCountries.nl: 'Netherlands',
      PrizeCountries.be: 'Belgium',
      PrizeCountries.ch: 'Switzerland',
      PrizeCountries.at: 'Austria',
      PrizeCountries.se: 'Sweden',
      PrizeCountries.no: 'Norway',
      PrizeCountries.dk: 'Denmark',
      PrizeCountries.fi: 'Finland',
      PrizeCountries.ie: 'Ireland',
      PrizeCountries.pt: 'Portugal',
      PrizeCountries.pl: 'Poland',
      PrizeCountries.cz: 'Czech Republic',
      PrizeCountries.gr: 'Greece',
      PrizeCountries.ro: 'Romania',
      PrizeCountries.hu: 'Hungary',
      PrizeCountries.cn: 'China',
      PrizeCountries.jp: 'Japan',
      PrizeCountries.kr: 'South Korea',
      PrizeCountries.ind: 'India',
      PrizeCountries.sg: 'Singapore',
      PrizeCountries.my: 'Malaysia',
      PrizeCountries.th: 'Thailand',
      PrizeCountries.vn: 'Vietnam',
      PrizeCountries.ph: 'Philippines',
      PrizeCountries.id: 'Indonesia',
      PrizeCountries.tw: 'Taiwan',
      PrizeCountries.hk: 'Hong Kong',
      PrizeCountries.au: 'Australia',
      PrizeCountries.nz: 'New Zealand',
      PrizeCountries.ae: 'UAE',
      PrizeCountries.sa: 'Saudi Arabia',
      PrizeCountries.il: 'Israel',
      PrizeCountries.tr: 'Turkey',
      PrizeCountries.za: 'South Africa',
      PrizeCountries.ng: 'Nigeria',
      PrizeCountries.eg: 'Egypt',
      PrizeCountries.ke: 'Kenya',
      PrizeCountries.ma: 'Morocco',
    };

    return StatefulBuilder(
      builder: (context, setRegionState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Countries (Required)',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 8),
            // Search bar
            TextField(
              controller: searchController,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                prefixIcon: Icon(
                  Symbols.search,
                  color: colorScheme.primary,
                  size: 20,
                ),
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setRegionState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            // Countries list with regions
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outline),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: regions.length,
                itemBuilder: (context, index) {
                  final regionName = regions.keys.elementAt(index);
                  final countriesInRegion = regions[regionName]!;

                  // Filter countries based on search
                  final filteredCountries = searchQuery.isEmpty
                      ? countriesInRegion
                      : countriesInRegion.where((country) {
                          final name =
                              countryNames[country]?.toLowerCase() ?? '';
                          return name.contains(searchQuery);
                        }).toList();

                  if (filteredCountries.isEmpty) return const SizedBox.shrink();

                  final allRegionSelected = filteredCountries.every(
                    (country) => selectedCountries.contains(country),
                  );

                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(left: 24, bottom: 8),
                    leading: Checkbox(
                      value: allRegionSelected,
                      tristate: true,
                      onChanged: (value) {
                        setRegionState(() {
                          if (value == true) {
                            // Select all countries in this region
                            selectedCountries.addAll(countriesInRegion);
                          } else {
                            // Deselect all countries in this region
                            selectedCountries.removeAll(countriesInRegion);
                          }
                          // If "All Countries" is selected, clear others
                          if (selectedCountries.contains(PrizeCountries.all) &&
                              regionName != 'All Countries') {
                            selectedCountries.remove(PrizeCountries.all);
                          }
                          // If selecting "All Countries", clear all others
                          if (regionName == 'All Countries' && value == true) {
                            selectedCountries.clear();
                            selectedCountries.add(PrizeCountries.all);
                          }
                          onChanged(selectedCountries);
                        });
                      },
                    ),
                    title: Text(
                      regionName,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: filteredCountries.map((country) {
                      return CheckboxListTile(
                        value: selectedCountries.contains(country),
                        onChanged: (value) {
                          setRegionState(() {
                            if (value == true) {
                              selectedCountries.add(country);
                              // If selecting a specific country, remove "All"
                              if (country != PrizeCountries.all) {
                                selectedCountries.remove(PrizeCountries.all);
                              } else {
                                // If selecting "All", clear all others
                                selectedCountries.clear();
                                selectedCountries.add(PrizeCountries.all);
                              }
                            } else {
                              selectedCountries.remove(country);
                            }
                            // Ensure at least one is selected (default to All)
                            if (selectedCountries.isEmpty) {
                              selectedCountries.add(PrizeCountries.all);
                            }
                            onChanged(selectedCountries);
                          });
                        },
                        title: Text(
                          countryNames[country] ?? country.toString(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Selected countries count
            Text(
              selectedCountries.contains(PrizeCountries.all)
                  ? 'Selected: All Countries'
                  : 'Selected: ${selectedCountries.length} ${selectedCountries.length == 1 ? 'country' : 'countries'}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrizeOptionsSection({
    required List<Map<String, dynamic>> prizeOptions,
    required List<Map<String, dynamic>> prizeOptionValues,
    required String prizeId,
    required VoidCallback onChanged,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.tune, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Prize Options (optional)',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final result = await _showAddOptionDialog(
                  prizeId: prizeId,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
                if (result != null) {
                  prizeOptions.add(result);
                  onChanged();
                }
              },
              icon: Icon(Symbols.add_circle_outline, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (prizeOptions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Symbols.tune, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No options added. Add options like Size, Color, RAM, etc. with their respective values.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colorScheme.outline),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: prizeOptions.length,
              itemBuilder: (context, index) {
                final option = prizeOptions[index];
                final optionId = option['id'];
                final values = prizeOptionValues
                    .where((v) => v['optionId'] == optionId)
                    .toList();

                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding:
                      const EdgeInsets.only(left: 24, right: 12, bottom: 8),
                  leading: Icon(
                    Symbols.label,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    option['name'] ?? 'Unnamed Option',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${values.length} ${values.length == 1 ? 'value' : 'values'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () async {
                          final result = await _showAddOptionValueDialog(
                            optionId: optionId,
                            optionName: option['name'] ?? '',
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          );
                          if (result != null) {
                            prizeOptionValues.add(result);
                            onChanged();
                          }
                        },
                        icon: Icon(Symbols.add, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          prizeOptions.removeAt(index);
                          prizeOptionValues.removeWhere(
                            (v) => v['optionId'] == optionId,
                          );
                          onChanged();
                        },
                        icon: Icon(Symbols.delete, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: TerminalColors.red,
                        ),
                      ),
                    ],
                  ),
                  children: values.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'No values added. Click + to add values.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ]
                      : values.map((value) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        value['label'] ?? 'Unnamed Value',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Symbols.paid,
                                            size: 14,
                                            color: TerminalColors.yellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${value['priceModifier'] >= 0 ? '+' : ''}${value['priceModifier']}',
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: TerminalColors.yellow,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Symbols.inventory_2,
                                            size: 14,
                                            color: colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${value['stock']}',
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final result =
                                        await _showEditOptionValueDialog(
                                      value: value,
                                      optionName: option['name'] ?? '',
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                    );
                                    if (result != null) {
                                      final idx = prizeOptionValues.indexOf(
                                        value,
                                      );
                                      if (idx != -1) {
                                        prizeOptionValues[idx] = result;
                                        onChanged();
                                      }
                                    }
                                  },
                                  icon: Icon(Symbols.edit, size: 16),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    prizeOptionValues.remove(value);
                                    onChanged();
                                  },
                                  icon: Icon(Symbols.delete, size: 16),
                                  style: IconButton.styleFrom(
                                    foregroundColor: TerminalColors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _showAddOptionDialog({
    required String prizeId,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) async {
    final nameController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outline),
          ),
          title: Row(
            children: [
              Icon(Symbols.label, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add Prize Option',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: nameController,
                label: 'Option Name (e.g., RAM, Color, Size)',
                icon: Symbols.label,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  GlobalNotificationService.instance.showError(
                    'Option name is required',
                  );
                  return;
                }
                Navigator.pop(context, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'createdAt': DateTime.now(),
                  'prizeId': prizeId,
                  'name': nameController.text.trim(),
                });
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showAddOptionValueDialog({
    required String optionId,
    required String optionName,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) async {
    final labelController = TextEditingController();
    final priceModifierController = TextEditingController(text: '0');
    final stockController = TextEditingController(text: '0');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outline),
          ),
          title: Row(
            children: [
              Icon(Symbols.add_circle, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add Value for "$optionName"',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: labelController,
                label: 'Value Label (e.g., 8GB, Red, Large)',
                icon: Symbols.label,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: priceModifierController,
                label: 'Price Modifier (coins)',
                icon: Symbols.paid,
                keyboardType: TextInputType.number,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: stockController,
                label: 'Stock',
                icon: Symbols.inventory_2,
                keyboardType: TextInputType.number,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  GlobalNotificationService.instance.showError(
                    'Value label is required',
                  );
                  return;
                }
                Navigator.pop(context, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'createdAt': DateTime.now(),
                  'optionId': optionId,
                  'label': labelController.text.trim(),
                  'priceModifier':
                      int.tryParse(priceModifierController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                });
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showEditOptionValueDialog({
    required Map<String, dynamic> value,
    required String optionName,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) async {
    final labelController =
        TextEditingController(text: value['label'] ?? '');
    final priceModifierController = TextEditingController(
      text: (value['priceModifier'] ?? 0).toString(),
    );
    final stockController =
        TextEditingController(text: (value['stock'] ?? 0).toString());

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outline),
          ),
          title: Row(
            children: [
              Icon(Symbols.edit, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit "$optionName" Value',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: labelController,
                label: 'Value Label',
                icon: Symbols.label,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: priceModifierController,
                label: 'Price Modifier (coins)',
                icon: Symbols.paid,
                keyboardType: TextInputType.number,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: stockController,
                label: 'Stock',
                icon: Symbols.inventory_2,
                keyboardType: TextInputType.number,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  GlobalNotificationService.instance.showError(
                    'Value label is required',
                  );
                  return;
                }
                Navigator.pop(context, {
                  'id': value['id'],
                  'createdAt': value['createdAt'],
                  'optionId': value['optionId'],
                  'label': labelController.text.trim(),
                  'priceModifier':
                      int.tryParse(priceModifierController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                });
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}
