import 'package:boot_app/services/navigation/navigation_service.dart';
import 'package:boot_app/services/order/Order_Service.dart';
import 'package:boot_app/services/prizes/Prize_Service.dart';
import 'package:boot_app/services/auth/Auth.dart';
import 'package:boot_app/services/slack/slack_manager.dart';
import 'package:boot_app/theme/terminal_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/prizes/Prize.dart';
import '/services/users/User.dart';
import '/widgets/shared_navigation_rail.dart';

class PrizeDetailsPage extends StatefulWidget {
  final Prize prize;

  const PrizeDetailsPage({super.key, required this.prize});

  @override
  State<PrizeDetailsPage> createState() => _PrizeDetailsPageState();
}

class _PrizeDetailsPageState extends State<PrizeDetailsPage> {
  Prize updatedPrize = Prize.empty();
  bool _isPrizeLoaded = false;
  bool _isSubmittingOrder = false;
  final Map<String, String> _selectedOptionValueByOptionId = {};

  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    updatedPrize = widget.prize;
    _loadPrizeDetails();
  }

  bool _isGrantPrize(Prize prize) {
    return prize.title.toLowerCase().contains('grant');
  }

  int _maxQuantityForPrize(Prize prize) {
    final cap = _isGrantPrize(prize) ? 500 : 20;
    return prize.stock.clamp(0, cap);
  }

  int _quantityForPrize(Prize prize) {
    final stockLimit = _maxQuantityForPrize(prize);
    final parsedQuantity = int.tryParse(_quantityController.text) ?? 1;
    return parsedQuantity.clamp(1, stockLimit == 0 ? 1 : stockLimit);
  }

  bool _userHasRequiredKey(Prize prize) {
    if (prize.key.isEmpty) return true;
    return UserService.currentUser?.keys.contains(prize.key) ?? false;
  }

  void _loadPrizeDetails() async {
    await PrizeService.updatePrizeWithOptions(updatedPrize);
    if (mounted) {
      setState(() {
        _initializeOptionSelections(updatedPrize);
        _isPrizeLoaded = true;
      });
    }
  }

  void _initializeOptionSelections(Prize prize) {
    final validOptionIds = <String>{};

    for (final option in prize.options) {
      validOptionIds.add(option.id);
      if (option.values.isEmpty) {
        _selectedOptionValueByOptionId.remove(option.id);
        continue;
      }

      final sortedValues = [...option.values]
        ..sort((a, b) => a.priceModifier.compareTo(b.priceModifier));
      final selectedValueId = _selectedOptionValueByOptionId[option.id];
      final hasSelectedValue = sortedValues.any(
        (value) => value.id == selectedValueId,
      );

      _selectedOptionValueByOptionId[option.id] = hasSelectedValue
          ? selectedValueId!
          : sortedValues.first.id;
    }

    _selectedOptionValueByOptionId.removeWhere(
      (optionId, _) => !validOptionIds.contains(optionId),
    );
  }

  void _selectOptionValue(String optionId, String valueId) {
    if (_selectedOptionValueByOptionId[optionId] == valueId) {
      return;
    }

    setState(() {
      _selectedOptionValueByOptionId[optionId] = valueId;
    });
  }

  List<MapEntry<String, int>> _selectedOptionAdjustments(Prize prize) {
    final adjustments = <MapEntry<String, int>>[];

    for (final option in prize.options) {
      final selectedValueId = _selectedOptionValueByOptionId[option.id];
      if (selectedValueId == null) {
        continue;
      }

      PrizeOptionValues? selectedValue;
      for (final value in option.values) {
        if (value.id == selectedValueId) {
          selectedValue = value;
          break;
        }
      }

      if (selectedValue == null || selectedValue.priceModifier == 0) {
        continue;
      }

      adjustments.add(
        MapEntry(
          '${option.name}: ${selectedValue.label}',
          selectedValue.priceModifier,
        ),
      );
    }

    return adjustments;
  }

  String _formatSignedCoins(int amount) {
    if (amount > 0) {
      return '+$amount';
    }
    return amount.toString();
  }

  List<PrizeOptionValues> _selectedOptionValues(Prize prize) {
    if (prize.options.isEmpty) {
      return [];
    }

    return prize.options
        .map((option) {
          final selectedValueId = _selectedOptionValueByOptionId[option.id];
          if (selectedValueId == null) {
            return null;
          }
          return option.values.firstWhere(
            (value) => value.id == selectedValueId,
            orElse: () => option.values.first,
          );
        })
        .whereType<PrizeOptionValues>()
        .toList();
  }

  Future<void> _showOrderSuccessDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🎉'),
          content: const Text('Your order has been successfully submitted.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                NavigationService.navigateTo(
                  context: context,
                  destination: AppDestination.home,
                  colorScheme: Theme.of(context).colorScheme,
                  textTheme: Theme.of(context).textTheme,
                );
              },
              child: const Text('Yay!'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleOrderPressed(Prize prize, int quantity) async {
    if (_isSubmittingOrder) {
      return;
    }

    setState(() {
      _isSubmittingOrder = true;
    });

    final orderSuccess = await OrderService.placeOrder(
      prize,
      quantity,
      _selectedOptionValues(prize),
    );

    if (!mounted) return;
    if (orderSuccess) {
      await _showOrderSuccessDialog();
      SlackManager.sendMessage(
        destination: UserService.currentUser?.slackUserId ?? '',
        message:
            "Heyo :roblox-wave:\n\nYour order for ${prize.title} has been received! :ultrafastparrot:\n\nWe'll send you another message once it's fulfilled. In the meantime, lets go over some order details:\n\n- Quantity: $quantity\n- Total Cost: ${prize.cost * quantity} coins\n\nKeep building your OS! :parrot_love:",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final prize = updatedPrize;

    return SharedNavigationRail(
      showAppBar: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surfaceContainerLowest,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Icon(Icons.storefront, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Shop'),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 700;
            final useVerticalLayout = constraints.maxWidth < 980;
            final horizontalPadding = isCompact ? 12.0 : 24.0;
            final panelRadius = isCompact ? 18.0 : 24.0;
            final panelMaxWidth = isCompact ? 640.0 : 1200.0;
            final imageFrameHeight = useVerticalLayout ? 260.0 : 420.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 18,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: panelMaxWidth),
                      child: _isPrizeLoaded
                          ? Material(
                              elevation: 8,
                              color: colorScheme.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  panelRadius,
                                ),
                                side: BorderSide(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isCompact ? 18 : 28),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: useVerticalLayout
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ..._buildDetailSection(
                                              prize,
                                              colorScheme,
                                              textTheme,
                                              imageFrameHeight,
                                            ),
                                            const SizedBox(height: 24),
                                            _buildCheckoutSection(
                                              prize,
                                              colorScheme,
                                              textTheme,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ..._buildDetailSection(
                                                    prize,
                                                    colorScheme,
                                                    textTheme,
                                                    imageFrameHeight,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 36),
                                            Expanded(
                                              child: _buildCheckoutSection(
                                                prize,
                                                colorScheme,
                                                textTheme,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagePanel({
    required Prize prize,
    required ColorScheme colorScheme,
    required double height,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // This backdrop stays visible through transparent image pixels.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surfaceContainerHigh,
                    colorScheme.surfaceContainerLow,
                  ],
                ),
              ),
            ),
            if (prize.picture != null && prize.picture!.isNotEmpty)
              Image.network(
                prize.picture!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(
                  alignment: Alignment.center,
                  color: colorScheme.surfaceContainerLow,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: colorScheme.outline,
                  ),
                ),
              )
            else
              Container(
                alignment: Alignment.center,
                color: colorScheme.surfaceContainerLow,
                child: Icon(Icons.redeem, size: 40, color: colorScheme.outline),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailSection(
    Prize prize,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double imageFrameHeight,
  ) {
    return [
      _buildImagePanel(
        prize: prize,
        colorScheme: colorScheme,
        height: imageFrameHeight,
      ),
      const SizedBox(height: 14),
      Text(
        prize.title,
        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(prize.description, style: textTheme.bodyMedium),
      if (prize.specs.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Text(prize.specs, style: textTheme.bodyMedium),
        ),
      ],
    ];
  }

  Widget _buildCheckoutSection(
    Prize prize,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final quantity = _quantityForPrize(prize);
    final maxQuantity = _maxQuantityForPrize(prize);
    final availableCoins = UserService.currentUser?.bootCoins ?? 0;
    final selectedOptionAdjustments = _selectedOptionAdjustments(prize);
    final selectedModifierPerItem = selectedOptionAdjustments.fold<int>(
      0,
      (sum, adjustment) => sum + adjustment.value,
    );
    final pricePerItem = prize.cost + selectedModifierPerItem;
    final totalCost = pricePerItem * quantity;
    final isRewardPrize = prize.type == PrizeType.reward;
    final hasKey = _userHasRequiredKey(prize);
    final isOutOfStock = prize.stock <= 0;
    final hasEnoughCoins = totalCost <= availableCoins;
    final canOrder =
        !isRewardPrize && !isOutOfStock && hasKey && hasEnoughCoins;

    final buttonText = isRewardPrize
        ? 'Reward prizes cannot be ordered'
        : isOutOfStock
        ? 'Out of Stock'
        : !hasKey
        ? 'Requires Key'
        : !hasEnoughCoins
        ? 'Need ${totalCost - availableCoins} more coins'
        : 'Order now';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Order Summary',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            'Quantity',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: maxQuantity >= 100 ? 3 : 2,
            decoration: InputDecoration(
              counterText: '',
              hintText: '1 - $maxQuantity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed == null) {
                return;
              }

              final clamped = parsed.clamp(
                1,
                maxQuantity == 0 ? 1 : maxQuantity,
              );

              if (clamped != parsed) {
                _quantityController.value = TextEditingValue(
                  text: clamped.toString(),
                  selection: TextSelection.collapsed(
                    offset: clamped.toString().length,
                  ),
                );
              }

              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Max quantity is $maxQuantity.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (prize.options.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var option in prize.options)
                    _buildOptionSection(option, colorScheme, textTheme),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryRow(
                  label: 'Price per item',
                  value: '$pricePerItem coins',
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                for (final adjustment in selectedOptionAdjustments) ...[
                  const SizedBox(height: 10),
                  _buildSummaryRow(
                    label: adjustment.key,
                    value: '${_formatSignedCoins(adjustment.value)} coins',
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                ],
                const SizedBox(height: 10),
                _buildSummaryRow(
                  label: 'Quantity',
                  value: quantity.toString(),
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  label: 'Total cost',
                  value: '$totalCost coins',
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                disabledForegroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: canOrder && !_isSubmittingOrder
                  ? () => _handleOrderPressed(prize, quantity)
                  : null,
              child: _isSubmittingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSection(
    PrizeOption option,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final sortedValues = [...option.values]
      ..sort((a, b) => a.priceModifier.compareTo(b.priceModifier));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(
            option.name,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var value in sortedValues) ...[
            _buildOptionValue(
              optionId: option.id,
              value: value,
              isSelected: _selectedOptionValueByOptionId[option.id] == value.id,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionValue({
    required String optionId,
    required PrizeOptionValues value,
    required bool isSelected,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSelected ? null : () => _selectOptionValue(optionId, value.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(
              alpha: isSelected ? 0.7 : 0.45,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value.label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.toll_rounded,
                    size: 16,
                    color: TerminalColors.yellow,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    value.priceModifier.toString(),
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
