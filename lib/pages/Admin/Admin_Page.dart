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
                  label: 'Challenges',
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
                onPressed: () => _showCreatePrizeDialog(),
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
            onPressed: () => _showEditPrizeDialog(prize),
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
                'Manage Challenges',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateChallengeDialog(),
                icon: const Icon(Symbols.add),
                label: const Text('Create Challenge'),
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
                        'No challenges yet',
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
                icon: Symbols.redeem,
                label: challenge.prize,
                color: TerminalColors.yellow,
                textTheme: textTheme,
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

  void _showCreatePrizeDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    final stockController = TextEditingController();
    final multiplierController = TextEditingController(text: '0');
    String? imageUrl;
    bool isUnlisted = false;

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
              unlisted: isUnlisted,
              multiplier: double.tryParse(multiplierController.text) ?? 1.0,
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
                  Text(
                    'Create New Prize',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
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
                                    controller: costController,
                                    label: 'Cost (coins)',
                                    icon: Symbols.paid,
                                    keyboardType: TextInputType.number,
                                    colorScheme: colorScheme,
                                    textTheme: textTheme,
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                            _buildTextField(
                              controller: multiplierController,
                              label: 'Coin Multiplier',
                              icon: Symbols.percent,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                            const SizedBox(height: 16),
                            // Unlisted toggle
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: colorScheme.outline),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.visibility_off,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unlisted',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Hide from shop',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isUnlisted,
                                    onChanged: (value) {
                                      setDialogState(() => isUnlisted = value);
                                    },
                                    activeColor: colorScheme.primary,
                                  ),
                                ],
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
                            Container(
                              height: 400,
                              child: _buildShopPrizeCard(
                                previewPrize,
                                colorScheme,
                                textTheme,
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
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        costController.text.isEmpty ||
                        stockController.text.isEmpty ||
                        imageUrl == null) {
                      GlobalNotificationService.instance.showError(
                        'Please fill all required fields and upload an image',
                      );
                      return;
                    }

                    try {
                      await SupabaseDB.upsertData(
                        table: 'prizes',
                        data: {
                          'title': titleController.text,
                          'description': descriptionController.text,
                          'cost': int.parse(costController.text),
                          'stock': int.parse(stockController.text),
                          'picture': imageUrl,
                          'unlisted': isUnlisted,
                          'multiplier': double.parse(multiplierController.text),
                        },
                      );
                      GlobalNotificationService.instance.showSuccess(
                        'Prize created successfully!',
                      );
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      AppLogger.error('Failed to create prize', e);
                      GlobalNotificationService.instance.showError(
                        'Failed to create prize',
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

  void _showEditPrizeDialog(Prize prize) {
    final titleController = TextEditingController(text: prize.title);
    final descriptionController = TextEditingController(
      text: prize.description,
    );
    final costController = TextEditingController(text: prize.cost.toString());
    final stockController = TextEditingController(text: prize.stock.toString());
    final multiplierController = TextEditingController(
      text: prize.multiplier.toString(),
    );
    String? imageUrl = prize.picture;
    bool isUnlisted = prize.unlisted;

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
              unlisted: isUnlisted,
              multiplier: double.tryParse(multiplierController.text) ?? 1.0,
            );

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
                    'Edit Prize',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
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
                                    controller: costController,
                                    label: 'Cost (coins)',
                                    icon: Symbols.paid,
                                    keyboardType: TextInputType.number,
                                    colorScheme: colorScheme,
                                    textTheme: textTheme,
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                            _buildTextField(
                              controller: multiplierController,
                              label: 'Coin Multiplier',
                              icon: Symbols.percent,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                                    : 'Change Image',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: imageUrl == null
                                    ? colorScheme.primary
                                    : TerminalColors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Unlisted toggle
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: colorScheme.outline),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.visibility_off,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unlisted',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Hide from shop (admin only)',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isUnlisted,
                                    onChanged: (value) {
                                      setDialogState(() => isUnlisted = value);
                                    },
                                    activeColor: colorScheme.primary,
                                  ),
                                ],
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
                            Container(
                              height: 400,
                              child: _buildShopPrizeCard(
                                previewPrize,
                                colorScheme,
                                textTheme,
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
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        costController.text.isEmpty ||
                        stockController.text.isEmpty ||
                        imageUrl == null) {
                      GlobalNotificationService.instance.showError(
                        'Please fill all required fields and upload an image',
                      );
                      return;
                    }

                    try {
                      await SupabaseDB.upsertData(
                        table: 'prizes',
                        data: {
                          'id': prize.id,
                          'title': titleController.text,
                          'description': descriptionController.text,
                          'cost': int.parse(costController.text),
                          'stock': int.parse(stockController.text),
                          'picture': imageUrl,
                          'unlisted': isUnlisted,
                          'multiplier': double.parse(multiplierController.text),
                        },
                      );
                      GlobalNotificationService.instance.showSuccess(
                        'Prize updated successfully!',
                      );
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      AppLogger.error('Failed to update prize', e);
                      GlobalNotificationService.instance.showError(
                        'Failed to update prize',
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
                  await SupabaseDB.deleteData(table: 'prizes', column: 'id', value: prize.id);
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
    String? selectedPrizeId = _prizes.isNotEmpty ? _prizes.first.id : null;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    ChallengeType selectedType = ChallengeType.normal;
    ChallengeDifficulty selectedDifficulty = ChallengeDifficulty.medium;
    bool isActive = true;

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
                    'Create New Challenge',
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
                      // Prize Dropdown
                      _prizes.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TerminalColors.yellow.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: TerminalColors.yellow,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.warning,
                                    color: TerminalColors.yellow,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No prizes available. Create prizes first.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: TerminalColors.yellow,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prize',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  child: DropdownButton<String>(
                                    value: selectedPrizeId,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    dropdownColor: colorScheme.surface,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    items: _prizes.map((prize) {
                                      return DropdownMenuItem<String>(
                                        value: prize.id,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Symbols.redeem,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                prize.title,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              ' (${prize.cost} coins)',
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        TerminalColors.yellow,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setDialogState(
                                        () => selectedPrizeId = value,
                                      );
                                    },
                                  ),
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
                        requirementsController.text.isEmpty ||
                        selectedPrizeId == null) {
                      GlobalNotificationService.instance.showError(
                        'Please fill all required fields',
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
                          'prize': selectedPrizeId,
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
                        'Challenge created successfully!',
                      );
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      AppLogger.error('Failed to create challenge', e);
                      GlobalNotificationService.instance.showError(
                        'Failed to create challenge',
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
}
