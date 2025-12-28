import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/widgets/shared_navigation_rail.dart';
import '/services/prizes/Prize.dart';
import '/services/prizes/Prize_Service.dart';
import '/services/users/User.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  List<Prize> _prizes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrizes();
  }

  Future<void> _loadPrizes() async {
    setState(() => _isLoading = true);
    try {
      final allPrizes = await PrizeService.fetchPrizes();
      // Filter out unlisted prizes and sort by cost (least to most expensive)
      final availablePrizes =
          allPrizes.where((prize) => !prize.unlisted).toList()
            ..sort((a, b) => a.cost.compareTo(b.cost));

      if (mounted) {
        setState(() {
          _prizes = availablePrizes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SharedNavigationRail(
      appBarActions: [
        // Coin balance
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: TerminalColors.yellow.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: TerminalColors.yellow.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.toll, size: 18, color: TerminalColors.yellow),
              const SizedBox(width: 6),
              Text(
                '${UserService.currentUser?.bootCoins ?? 0}',
                style: textTheme.titleSmall?.copyWith(
                  color: TerminalColors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Shopping cart button
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            onPressed: () {
              // TODO: Add cart functionality
            },
            icon: Icon(
              Symbols.shopping_cart,
              size: 22,
              color: colorScheme.primary,
            ),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: colorScheme.outline, width: 1),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
      child: Container(
        color: colorScheme.surface,
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading prizes...',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : _prizes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.storefront,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No prizes available',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for new items!',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getGridColumns(context),
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: _prizes.length,
                itemBuilder: (context, index) {
                  return _buildPrizeCard(
                    _prizes[index],
                    colorScheme,
                    textTheme,
                  );
                },
              ),
      ),
    );
  }

  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 4;
    if (width > 1000) return 3;
    if (width > 600) return 2;
    return 1;
  }

  Widget _buildPrizeCard(
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
