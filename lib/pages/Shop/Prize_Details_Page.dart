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
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final prize = widget.prize;

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
                      child: Material(
                        elevation: 8,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(panelRadius),
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.45),
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
    final totalCost = prize.cost * quantity;
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
          //TODO: PRIZE VARIANTS
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
                  value: '${prize.cost} coins',
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
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
              onPressed: canOrder
                  ? () {
                      // TODO: submit order
                    }
                  : null,
              child: Text(buttonText),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You will be redirected to reauthenticate.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
}
