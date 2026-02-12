import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/widgets/shared_navigation_rail.dart';
import '/services/prizes/Prize.dart';
import '/services/prizes/Prize_Service.dart';
import '/services/users/User.dart';
import '/services/notifications/notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  PrizeCountries _selectedCountry = PrizeCountries.all;
  bool _isDetectingCountry = false;

  @override
  void initState() {
    super.initState();
    _loadPrizes();
    _loadCart();
    _detectUserCountry();
  }

  Future<void> _detectUserCountry() async {
    setState(() => _isDetectingCountry = true);
    try {
      // Use ipapi.co for geolocation (free tier: 1000 requests/day)
      final response = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryCode = (data['country_code'] as String?)?.toLowerCase();
        if (countryCode != null) {
          // Map country code to PrizeCountries enum
          final country = _countryCodeToEnum(countryCode);
          if (country != null && mounted) {
            setState(() {
              _selectedCountry = country;
              _isDetectingCountry = false;
            });
            _applyFilters();
          }
        }
      }
    } catch (e) {
      // Silently fail and keep default "all" selection
    }
    if (mounted) {
      setState(() => _isDetectingCountry = false);
    }
  }

  PrizeCountries? _countryCodeToEnum(String code) {
    final mapping = {
      'us': PrizeCountries.us,
      'ca': PrizeCountries.ca,
      'mx': PrizeCountries.mx,
      'ar': PrizeCountries.ar,
      'br': PrizeCountries.br,
      'cl': PrizeCountries.cl,
      'co': PrizeCountries.co,
      'pe': PrizeCountries.pe,
      've': PrizeCountries.ve,
      'ec': PrizeCountries.ec,
      'bo': PrizeCountries.bo,
      'py': PrizeCountries.py,
      'uy': PrizeCountries.uy,
      'gb': PrizeCountries.gb,
      'de': PrizeCountries.de,
      'fr': PrizeCountries.fr,
      'it': PrizeCountries.it,
      'es': PrizeCountries.es,
      'nl': PrizeCountries.nl,
      'be': PrizeCountries.be,
      'ch': PrizeCountries.ch,
      'at': PrizeCountries.at,
      'se': PrizeCountries.se,
      'no': PrizeCountries.no,
      'dk': PrizeCountries.dk,
      'fi': PrizeCountries.fi,
      'ie': PrizeCountries.ie,
      'pt': PrizeCountries.pt,
      'pl': PrizeCountries.pl,
      'cz': PrizeCountries.cz,
      'gr': PrizeCountries.gr,
      'ro': PrizeCountries.ro,
      'hu': PrizeCountries.hu,
      'cn': PrizeCountries.cn,
      'jp': PrizeCountries.jp,
      'kr': PrizeCountries.kr,
      'in': PrizeCountries.ind,
      'sg': PrizeCountries.sg,
      'my': PrizeCountries.my,
      'th': PrizeCountries.th,
      'vn': PrizeCountries.vn,
      'ph': PrizeCountries.ph,
      'id': PrizeCountries.id,
      'tw': PrizeCountries.tw,
      'hk': PrizeCountries.hk,
      'au': PrizeCountries.au,
      'nz': PrizeCountries.nz,
      'ae': PrizeCountries.ae,
      'sa': PrizeCountries.sa,
      'il': PrizeCountries.il,
      'tr': PrizeCountries.tr,
      'za': PrizeCountries.za,
      'ng': PrizeCountries.ng,
      'eg': PrizeCountries.eg,
      'ke': PrizeCountries.ke,
      'ma': PrizeCountries.ma,
    };
    return mapping[code];
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
        _applyFilters();
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

  void _applyFilters() {
    setState(() {
      // Filter by country first
      final userKeys = Set<String>.from(UserService.currentUser?.keys ?? []);
      final available = <Prize>[];
      final locked = <Prize>[];

      for (final prize in _allPrizes) {
        // Check country eligibility
        final isCountryEligible =
            _selectedCountry == PrizeCountries.all ||
            prize.countries.contains(PrizeCountries.all) ||
            prize.countries.contains(_selectedCountry);

        if (!isCountryEligible) continue;

        // Check prize type and key requirements
        if (prize.type == PrizeType.normal || prize.type == PrizeType.grant) {
          available.add(prize);
        } else if (prize.type == PrizeType.keyed) {
          if (prize.key.isNotEmpty && userKeys.contains(prize.key)) {
            available.add(prize);
          } else {
            locked.add(prize);
          }
        }
      }

      _availablePrizes = available;
      _lockedPrizes = locked;

      // Apply sorting
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
        // Check if it's a grant prize
        final prize = _allPrizes.firstWhere(
          (p) => p.id == prizeId,
          orElse: Prize.empty,
        );
        // For grants, default to $10; for others, default to quantity 1
        _quantities[prizeId] = prize.type == PrizeType.grant ? 10 : 1;
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
            const SizedBox(width: 16),
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
                      // Shop notice
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: TerminalColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: TerminalColors.blue.withValues(
                                  alpha: 0.3,
                                ),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Symbols.construction,
                                  size: 28,
                                  color: TerminalColors.blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'More OSes have to be shipped before the Shop can have its grand opening. What are you waiting for? Go build your OS.',
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Filters section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          child: Row(
                            children: [
                              // Country filter
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.outline,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Symbols.public,
                                        size: 20,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      if (_isDetectingCountry)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: DropdownButton<PrizeCountries>(
                                            value: _selectedCountry,
                                            isExpanded: true,
                                            underline: const SizedBox(),
                                            onChanged: (country) {
                                              if (country != null) {
                                                setState(
                                                  () => _selectedCountry =
                                                      country,
                                                );
                                                _applyFilters();
                                              }
                                            },
                                            items: _getAllCountries().map((
                                              country,
                                            ) {
                                              return DropdownMenuItem(
                                                value: country,
                                                child: Text(
                                                  _getCountryName(country),
                                                  style: textTheme.bodyMedium,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Sort filter
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.outline,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Symbols.sort,
                                        size: 20,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButton<SortOption>(
                                          value: _sortOption,
                                          isExpanded: true,
                                          underline: const SizedBox(),
                                          onChanged: (option) {
                                            if (option != null) {
                                              setState(
                                                () => _sortOption = option,
                                              );
                                              _applyFilters();
                                            }
                                          },
                                          items: [
                                            DropdownMenuItem(
                                              value: SortOption.priceAscending,
                                              child: Text(
                                                'Price: Low to High',
                                                style: textTheme.bodyMedium,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: SortOption.priceDescending,
                                              child: Text(
                                                'Price: High to Low',
                                                style: textTheme.bodyMedium,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: SortOption.alphabetical,
                                              child: Text(
                                                'Alphabetical',
                                                style: textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
    final bool isGrant = prize.type == PrizeType.grant;

    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: InkWell(
        onTap: isLocked
            ? null
            : () async {
                // Navigate using URL routing and wait for result
                final result = await Navigator.pushNamed(
                  context,
                  '/prizes/${prize.id}',
                );
                // If cart was updated, refresh the shop data
                if (result == true && mounted) {
                  setState(() {
                    // This will rebuild and refresh the cart items display
                  });
                }
              },
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
                                              'Requires key',
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        TerminalColors.yellow,
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
                                  : TerminalColors.yellow.withValues(
                                      alpha: 0.9,
                                    ),
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
                      // Quantity/Amount selector - only shown when in cart
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
                                isGrant ? 'Amount:' : 'Quantity:',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: quantity > (isGrant ? 1 : 1)
                                    ? () => _updateQuantity(prize.id, -1)
                                    : null,
                                icon: const Icon(Symbols.remove, size: 18),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(32, 32),
                                  padding: EdgeInsets.zero,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                ),
                              ),
                              Container(
                                width: 50,
                                alignment: Alignment.center,
                                child: Text(
                                  isGrant ? '\$$quantity' : '$quantity',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isGrant
                                        ? TerminalColors.green
                                        : null,
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
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<PrizeCountries> _getAllCountries() {
    // Return all countries in alphabetical order
    final allCountries = [
      PrizeCountries.all,
      PrizeCountries.ar, // Argentina
      PrizeCountries.au, // Australia
      PrizeCountries.at, // Austria
      PrizeCountries.be, // Belgium
      PrizeCountries.bo, // Bolivia
      PrizeCountries.br, // Brazil
      PrizeCountries.ca, // Canada
      PrizeCountries.cl, // Chile
      PrizeCountries.cn, // China
      PrizeCountries.co, // Colombia
      PrizeCountries.cz, // Czech Republic
      PrizeCountries.dk, // Denmark
      PrizeCountries.ec, // Ecuador
      PrizeCountries.eg, // Egypt
      PrizeCountries.fi, // Finland
      PrizeCountries.fr, // France
      PrizeCountries.de, // Germany
      PrizeCountries.gr, // Greece
      PrizeCountries.hk, // Hong Kong
      PrizeCountries.hu, // Hungary
      PrizeCountries.ind, // India
      PrizeCountries.id, // Indonesia
      PrizeCountries.ie, // Ireland
      PrizeCountries.il, // Israel
      PrizeCountries.it, // Italy
      PrizeCountries.jp, // Japan
      PrizeCountries.ke, // Kenya
      PrizeCountries.kr, // South Korea
      PrizeCountries.ma, // Morocco
      PrizeCountries.my, // Malaysia
      PrizeCountries.mx, // Mexico
      PrizeCountries.nl, // Netherlands
      PrizeCountries.nz, // New Zealand
      PrizeCountries.ng, // Nigeria
      PrizeCountries.no, // Norway
      PrizeCountries.py, // Paraguay
      PrizeCountries.pe, // Peru
      PrizeCountries.ph, // Philippines
      PrizeCountries.pl, // Poland
      PrizeCountries.pt, // Portugal
      PrizeCountries.ro, // Romania
      PrizeCountries.sa, // Saudi Arabia
      PrizeCountries.sg, // Singapore
      PrizeCountries.za, // South Africa
      PrizeCountries.es, // Spain
      PrizeCountries.se, // Sweden
      PrizeCountries.ch, // Switzerland
      PrizeCountries.tw, // Taiwan
      PrizeCountries.th, // Thailand
      PrizeCountries.tr, // Turkey
      PrizeCountries.ae, // UAE
      PrizeCountries.gb, // United Kingdom
      PrizeCountries.us, // United States
      PrizeCountries.uy, // Uruguay
      PrizeCountries.ve, // Venezuela
      PrizeCountries.vn, // Vietnam
    ];
    return allCountries;
  }

  List<PrizeCountries> _getPopularCountries() {
    return [
      PrizeCountries.us,
      PrizeCountries.ca,
      PrizeCountries.gb,
      PrizeCountries.au,
      PrizeCountries.de,
      PrizeCountries.fr,
      PrizeCountries.jp,
      PrizeCountries.ind,
      PrizeCountries.br,
      PrizeCountries.mx,
    ];
  }

  String _getCountryName(PrizeCountries country) {
    final countryNames = {
      PrizeCountries.all: 'All Countries',
      PrizeCountries.us: 'United States',
      PrizeCountries.ca: 'Canada',
      PrizeCountries.mx: 'Mexico',
      PrizeCountries.gb: 'United Kingdom',
      PrizeCountries.de: 'Germany',
      PrizeCountries.fr: 'France',
      PrizeCountries.it: 'Italy',
      PrizeCountries.es: 'Spain',
      PrizeCountries.au: 'Australia',
      PrizeCountries.nz: 'New Zealand',
      PrizeCountries.jp: 'Japan',
      PrizeCountries.kr: 'South Korea',
      PrizeCountries.cn: 'China',
      PrizeCountries.ind: 'India',
      PrizeCountries.br: 'Brazil',
      PrizeCountries.ar: 'Argentina',
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
      PrizeCountries.sg: 'Singapore',
      PrizeCountries.my: 'Malaysia',
      PrizeCountries.th: 'Thailand',
      PrizeCountries.vn: 'Vietnam',
      PrizeCountries.ph: 'Philippines',
      PrizeCountries.id: 'Indonesia',
      PrizeCountries.tw: 'Taiwan',
      PrizeCountries.hk: 'Hong Kong',
      PrizeCountries.ae: 'UAE',
      PrizeCountries.sa: 'Saudi Arabia',
      PrizeCountries.il: 'Israel',
      PrizeCountries.tr: 'Turkey',
      PrizeCountries.za: 'South Africa',
      PrizeCountries.ng: 'Nigeria',
      PrizeCountries.eg: 'Egypt',
      PrizeCountries.ke: 'Kenya',
      PrizeCountries.ma: 'Morocco',
      PrizeCountries.cl: 'Chile',
      PrizeCountries.co: 'Colombia',
      PrizeCountries.pe: 'Peru',
      PrizeCountries.ve: 'Venezuela',
      PrizeCountries.ec: 'Ecuador',
      PrizeCountries.bo: 'Bolivia',
      PrizeCountries.py: 'Paraguay',
      PrizeCountries.uy: 'Uruguay',
    };
    return countryNames[country] ??
        country.toString().split('.').last.toUpperCase();
  }
}

// Cart Dialog Widget
class _CartDialog extends StatefulWidget {
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

  @override
  State<_CartDialog> createState() => _CartDialogState();
}

class _CartDialogState extends State<_CartDialog> {
  int _calculateTotal() {
    int total = 0;
    for (final prizeId in widget.cartItems) {
      final prize = widget.allPrizes.firstWhere(
        (p) => p.id == prizeId,
        orElse: Prize.empty,
      );
      final quantity = widget.quantities[prizeId] ?? 1;
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
    final isCheckoutEnabled = widget.disabledReason == null;

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
              child: widget.cartItems.isEmpty
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
                      itemCount: widget.cartItems.length,
                      itemBuilder: (context, index) {
                        final prizeId = widget.cartItems.elementAt(index);
                        final prize = widget.allPrizes.firstWhere(
                          (p) => p.id == prizeId,
                          orElse: Prize.empty,
                        );
                        final quantity = widget.quantities[prizeId] ?? 1;
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
                                  onPressed: () {
                                    widget.onRemoveItem(prizeId);
                                    setState(() {});
                                  },
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
                      onPressed:
                          isCheckoutEnabled && widget.cartItems.isNotEmpty
                          ? widget.onCheckout
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
                            : (widget.disabledReason ?? 'Cart Empty'),
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
                  if (!isCheckoutEnabled && widget.cartItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.disabledReason == 'Insufficient Coins'
                          ? 'You need ${cartTotal - userCoins} more coins'
                          : widget.disabledReason ?? '',
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
