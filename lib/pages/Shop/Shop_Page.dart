import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/widgets/shared_navigation_rail.dart';
import '/services/prizes/Prize.dart';
import '/services/prizes/Prize_Service.dart';
import '/services/users/User.dart';
import '/services/notifications/notifications.dart';

enum SortOption { priceAscending, priceDescending, alphabetical }

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  static const int DEFAULT_MAX_QUANTITY = 99;

  List<Prize> _allPrizes = [];
  List<Prize> _availablePrizes = [];
  List<Prize> _lockedPrizes = [];
  Set<String> _cartItems = {};
  Map<String, int> _quantities = {}; // Track quantity for each prize
  bool _isLoading = true;
  SortOption _sortOption = SortOption.priceAscending;

  @override
  void initState() {
    super.initState();
    _loadPrizes();
    _loadCart();
  }

  void _loadCart() {
    final currentUser = UserService.currentUser;
    if (currentUser != null) {
      setState(() {
        _cartItems = Set<String>.from(currentUser.cart);
      });
    }
  }

  Future<void> _loadPrizes() async {
    setState(() => _isLoading = true);
    try {
      final allPrizes = await PrizeService.fetchPrizes();
      final userKeys = Set<String>.from(UserService.currentUser?.keys ?? []);

      // Filter out unlisted prizes
      final listedPrizes = allPrizes
          .where((prize) => prize.type != PrizeType.reward)
          .toList();

      // Separate prizes into available and locked
      final available = <Prize>[];
      final locked = <Prize>[];

      for (final prize in listedPrizes) {
        if (prize.type == PrizeType.normal) {
          available.add(prize);
        } else if (prize.type == PrizeType.keyed) {
          // If user has the required key, add to available, otherwise locked
          if (prize.key.isNotEmpty && userKeys.contains(prize.key)) {
            available.add(prize);
          } else {
            locked.add(prize);
          }
        }
      }

      if (mounted) {
        setState(() {
          _allPrizes = listedPrizes;
          _availablePrizes = available;
          _lockedPrizes = locked;
        });
        _applySorting();
        await _cleanupCart();
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cleanupCart() async {
    // Remove items from cart that are deleted or out of stock
    final validPrizeIds = _allPrizes
        .where((p) => p.stock > 0)
        .map((p) => p.id)
        .toSet();

    final itemsToRemove = _cartItems
        .where((id) => !validPrizeIds.contains(id))
        .toList();

    if (itemsToRemove.isNotEmpty) {
      // Store original state for rollback
      final originalCartItems = Set<String>.from(_cartItems);
      final originalQuantities = Map<String, int>.from(_quantities);

      setState(() {
        for (final id in itemsToRemove) {
          _cartItems.remove(id);
          _quantities.remove(id);
        }
      });

      // Update user's cart in the backend
      await _syncUserCart(
        originalCartItems: originalCartItems,
        originalQuantities: originalQuantities,
      );
    }
  }

  void _applySorting() {
    setState(() {
      switch (_sortOption) {
        case SortOption.priceAscending:
          _availablePrizes.sort((a, b) => a.cost.compareTo(b.cost));
          break;
        case SortOption.priceDescending:
          _availablePrizes.sort((a, b) => b.cost.compareTo(a.cost));
          break;
        case SortOption.alphabetical:
          _availablePrizes.sort((a, b) => a.title.compareTo(b.title));
          break;
      }
    });
  }

  /// Synchronizes the local cart state with the backend.
  /// Includes error handling with rollback on failure.
  Future<void> _syncUserCart({
    Set<String>? originalCartItems,
    Map<String, int>? originalQuantities,
  }) async {
    final currentUser = UserService.currentUser;
    if (currentUser == null) return;

    try {
      currentUser.cart = _cartItems.toList();
      await UserService.updateUser();
    } catch (e) {
      // Revert local cart changes on error if originals provided
      if (originalCartItems != null || originalQuantities != null) {
        setState(() {
          if (originalCartItems != null) _cartItems = originalCartItems;
          if (originalQuantities != null) _quantities = originalQuantities;
        });
        // Restore user cart to original state
        if (originalCartItems != null) {
          currentUser.cart = originalCartItems.toList();
        }
      }

      // Show error to user
      GlobalNotificationService.instance.showError(
        'Failed to save cart changes. Please try again.',
      );
    }
  }

  void _toggleCartItem(String prizeId) {
    // Store original state for rollback
    final originalCartItems = Set<String>.from(_cartItems);
    final originalQuantities = Map<String, int>.from(_quantities);

    setState(() {
      if (_cartItems.contains(prizeId)) {
        _cartItems.remove(prizeId);
        _quantities.remove(prizeId);
      } else {
        _cartItems.add(prizeId);
        _quantities[prizeId] = 1; // Default quantity is 1
      }
    });

    // Update user's cart in the backend
    _syncUserCart(
      originalCartItems: originalCartItems,
      originalQuantities: originalQuantities,
    );
  }

  void _updateQuantity(String prizeId, int delta) {
    // Get the prize to check stock
    final prize = _allPrizes.firstWhere(
      (p) => p.id == prizeId,
      orElse: Prize.empty,
    );

    // Return early if prize not found
    if (prize.id.isEmpty) return;

    // Store original state for rollback
    final originalCartItems = Set<String>.from(_cartItems);
    final originalQuantities = Map<String, int>.from(_quantities);

    setState(() {
      final currentQty = _quantities[prizeId] ?? 1;
      final maxQty = prize.stock > 0 ? prize.stock : 0;
      final newQty = (currentQty + delta).clamp(0, maxQty);

      if (newQty == 0) {
        // Remove from cart when quantity reaches 0
        _cartItems.remove(prizeId);
        _quantities.remove(prizeId);
      } else {
        _quantities[prizeId] = newQty;
      }
    });

    // Update user's cart in the backend
    _syncUserCart(
      originalCartItems: originalCartItems,
      originalQuantities: originalQuantities,
    );
  }

  int _calculateCartTotal() {
    int total = 0;
    for (final prizeId in _cartItems) {
      final prize = _allPrizes.firstWhere(
        (p) => p.id == prizeId,
        orElse: Prize.empty,
      );
      final quantity = _quantities[prizeId] ?? 1;
      total += prize.cost * quantity;
    }
    return total;
  }

  String? _getCheckoutDisabledReason() {
    if (_cartItems.isEmpty) return null;

    final userCoins = UserService.currentUser?.bootCoins ?? 0;
    final cartTotal = _calculateCartTotal();

    // Check if all items are in stock with sufficient quantity
    for (final prizeId in _cartItems) {
      final prize = _allPrizes.firstWhere(
        (p) => p.id == prizeId,
        orElse: Prize.empty,
      );
      final quantity = _quantities[prizeId] ?? 1;

      // If prize doesn't exist
      if (prize.id.isEmpty) {
        return 'Item no longer available';
      }

      // If prize is out of stock or quantity exceeds stock
      if (prize.stock <= 0) {
        return 'Item out of stock';
      }

      if (quantity > prize.stock) {
        return 'Insufficient stock';
      }
    }

    // Check if user can afford
    if (userCoins < cartTotal) {
      return 'Insufficient Coins';
    }

    return null; // No disabled reason, checkout is enabled
  }

  void _showCartDialog() {
    final disabledReason = _getCheckoutDisabledReason();
    showDialog(
      context: context,
      builder: (context) => _CartDialog(
        cartItems: _cartItems,
        allPrizes: _allPrizes,
        quantities: _quantities,
        onRemoveItem: _toggleCartItem,
        disabledReason: disabledReason,
        onCheckout: disabledReason == null
            ? () {
                // TODO: Implement checkout
                Navigator.pop(context);
                GlobalNotificationService.instance.showInfo(
                  'Checkout not yet implemented',
                );
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SharedNavigationRail(
      showAppBar: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surfaceContainerLowest,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.storefront, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Shop',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Sort dropdown
            PopupMenuButton<SortOption>(
              icon: Icon(Symbols.sort, color: colorScheme.primary),
              onSelected: (option) {
                setState(() => _sortOption = option);
                _applySorting();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortOption.priceAscending,
                  child: Row(
                    children: [
                      Icon(Symbols.arrow_upward, size: 18),
                      const SizedBox(width: 8),
                      const Text('Price: Low to High'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortOption.priceDescending,
                  child: Row(
                    children: [
                      Icon(Symbols.arrow_downward, size: 18),
                      const SizedBox(width: 8),
                      const Text('Price: High to Low'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortOption.alphabetical,
                  child: Row(
                    children: [
                      Icon(Symbols.sort_by_alpha, size: 18),
                      const SizedBox(width: 8),
                      const Text('Alphabetical'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _showCartDialog,
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
                  if (_cartItems.isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: TerminalColors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${_cartItems.length}',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
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
            : _availablePrizes.isEmpty && _lockedPrizes.isEmpty
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
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: CustomScrollView(
                    slivers: [
                      // Available prizes section
                      if (_availablePrizes.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _getGridColumns(context),
                                  childAspectRatio: 0.68,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _buildPrizeCard(
                                _availablePrizes[index],
                                colorScheme,
                                textTheme,
                                isLocked: false,
                              );
                            }, childCount: _availablePrizes.length),
                          ),
                        ),
                      ],

                      // Locked prizes section
                      if (_lockedPrizes.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Locked Prizes',
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Unlock these prizes by obtaining the required keys',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _getGridColumns(context),
                                  childAspectRatio: 0.68,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _buildPrizeCard(
                                _lockedPrizes[index],
                                colorScheme,
                                textTheme,
                                isLocked: true,
                              );
                            }, childCount: _lockedPrizes.length),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
    TextTheme textTheme, {
    required bool isLocked,
  }) {
    final bool isOutOfStock = prize.stock <= 0;
    final bool isLowStock = prize.stock > 0 && prize.stock <= 5;
    final bool isInCart = _cartItems.contains(prize.id);
    final int quantity = _quantities[prize.id] ?? 1;

    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLocked
                ? colorScheme.outline.withValues(alpha: 0.3)
                : colorScheme.outline,
            width: 1,
          ),
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

                    // Locked overlay
                    if (isLocked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Symbols.lock,
                                  size: 48,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'LOCKED',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (prize.key.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TerminalColors.yellow.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: TerminalColors.yellow,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Symbols.key,
                                          size: 14,
                                          color: TerminalColors.yellow,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Requires: ${prize.key}',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: TerminalColors.yellow,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Stock badge
                    if (!isLocked && (isOutOfStock || isLowStock))
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

            // Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    prize.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: isLocked
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    isLocked
                        ? 'You need the corresponding key to unlock this prize'
                        : prize.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Price - Subtle, below description
                  Row(
                    children: [
                      Icon(
                        Symbols.toll,
                        size: 16,
                        color: TerminalColors.yellow.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${prize.cost}',
                        style: textTheme.titleMedium?.copyWith(
                          color: TerminalColors.yellow.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'coins',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stock info (only if locked or out of stock)
                  if (isLocked || isOutOfStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.inventory_2,
                            size: 16,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Stock: ${prize.stock}',
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
            ),

            // Quantity selector and Add to Cart button (full width at bottom)
            if (!isLocked && !isOutOfStock) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Quantity selector - only shown when in cart
                    if (isInCart)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Quantity:',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _updateQuantity(prize.id, -1),
                              icon: const Icon(Symbols.remove, size: 18),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    colorScheme.surfaceContainerHigh,
                              ),
                            ),
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Text(
                                '$quantity',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _updateQuantity(prize.id, 1),
                              icon: const Icon(Symbols.add, size: 18),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    colorScheme.surfaceContainerHigh,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Add to Cart button (only shown when not in cart)
                    if (!isInCart)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleCartItem(prize.id),
                          icon: const Icon(Symbols.add_shopping_cart, size: 20),
                          label: Text(
                            'Add to Cart',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.green,
                            foregroundColor: TerminalColors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: TerminalColors.green,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Cart Dialog Widget
class _CartDialog extends StatelessWidget {
  final Set<String> cartItems;
  final List<Prize> allPrizes;
  final Map<String, int> quantities;
  final Function(String) onRemoveItem;
  final VoidCallback? onCheckout;
  final String? disabledReason;

  const _CartDialog({
    required this.cartItems,
    required this.allPrizes,
    required this.quantities,
    required this.onRemoveItem,
    this.onCheckout,
    this.disabledReason,
  });

  int _calculateTotal() {
    int total = 0;
    for (final prizeId in cartItems) {
      final prize = allPrizes.firstWhere(
        (p) => p.id == prizeId,
        orElse: Prize.empty,
      );
      final quantity = quantities[prizeId] ?? 1;
      total += prize.cost * quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userCoins = UserService.currentUser?.bootCoins ?? 0;
    final cartTotal = _calculateTotal();
    final isCheckoutEnabled = disabledReason == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Symbols.shopping_cart, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Shopping Cart',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Cart items
            Expanded(
              child: cartItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Symbols.shopping_cart,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your cart is empty',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final prizeId = cartItems.elementAt(index);
                        final prize = allPrizes.firstWhere(
                          (p) => p.id == prizeId,
                          orElse: Prize.empty,
                        );
                        final quantity = quantities[prizeId] ?? 1;
                        final itemTotal = prize.cost * quantity;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  prize.picture != null &&
                                      prize.picture!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        prize.picture!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Symbols.redeem,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Symbols.redeem,
                                      color: colorScheme.outline,
                                    ),
                            ),
                            title: Text(
                              prize.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(
                                  Symbols.toll,
                                  size: 14,
                                  color: TerminalColors.yellow,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${prize.cost}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: TerminalColors.yellow,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Qty: $quantity',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Symbols.delete, size: 20),
                                  color: TerminalColors.red,
                                  onPressed: () => onRemoveItem(prizeId),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer with total and checkout
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: colorScheme.outline, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Symbols.toll,
                            size: 20,
                            color: TerminalColors.yellow,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$cartTotal',
                            style: textTheme.titleLarge?.copyWith(
                              color: TerminalColors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isCheckoutEnabled && cartItems.isNotEmpty
                          ? onCheckout
                          : null,
                      icon: Icon(
                        isCheckoutEnabled
                            ? Symbols.shopping_bag
                            : Symbols.block,
                        size: 20,
                      ),
                      label: Text(
                        isCheckoutEnabled
                            ? 'Checkout'
                            : (disabledReason ?? 'Cart Empty'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckoutEnabled
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: isCheckoutEnabled
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!isCheckoutEnabled && cartItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      disabledReason == 'Insufficient Coins'
                          ? 'You need ${cartTotal - userCoins} more coins'
                          : disabledReason ?? '',
                      style: textTheme.bodySmall?.copyWith(
                        color: TerminalColors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
