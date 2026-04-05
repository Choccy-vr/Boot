import 'dart:convert';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/prizes/Prize.dart';
import 'package:boot_app/services/prizes/Prize_Service.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:boot_app/theme/terminal_theme.dart';
import 'package:boot_app/widgets/shared_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  static const double _contentMaxWidth = 1280;
  static const bool _showAllPrizesInNewSectionForTesting = false;

  final TextEditingController _searchController = TextEditingController();
  final List<PrizeCountries> _regions = PrizeCountries.values;
  PrizeCountries _selectedRegion = PrizeCountries.all;
  String _selectedSort = 'cost_asc';
  bool _isDetectingCountry = false;
  bool _isLoadingPrizes = true;
  bool _isNewPrizesCollapsed = false;
  final ScrollController _newPrizesScrollController = ScrollController();
  List<Prize> _allPrizes = [];
  List<Prize> _newPrizes = [];
  List<Prize> _filteredPrizes = [];
  List<Prize> _keyedPrizes = [];

  static const Map<String, PrizeCountries> _alpha2ToPrizeCountry = {
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
    'uk': PrizeCountries.gb,
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

  String _regionLabel(PrizeCountries region) {
    return region == PrizeCountries.all
        ? 'All'
        : prizeCountryDisplayName(region);
  }

  double _regionDropdownIdealWidth(TextTheme textTheme) {
    final textStyle = textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    var maxLabelWidth = 0.0;

    for (final region in _regions) {
      final painter = TextPainter(
        text: TextSpan(text: _regionLabel(region), style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > maxLabelWidth) {
        maxLabelWidth = painter.width;
      }
    }

    // Add room for horizontal padding and the dropdown icon.
    return (maxLabelWidth + 96).clamp(220.0, 420.0);
  }

  PrizeCountries? _countryCodeToEnum(String countryCode) {
    final normalizedCode = countryCode.trim().toLowerCase();
    return _alpha2ToPrizeCountry[normalizedCode];
  }

  bool _userHasPrizeKey(Prize prize) {
    final currentUserKeys = UserService.currentUser?.keys;
    if (currentUserKeys == null || currentUserKeys.isEmpty) {
      return false;
    }

    return currentUserKeys.contains(prize.key);
  }

  Future<void> _loadPrizes() async {
    if (!mounted) return;
    setState(() => _isLoadingPrizes = true);

    await PrizeService.updatePrizes();
    if (!mounted) return;

    _allPrizes = List<Prize>.from(PrizeService.prizes);
    _setNewPrizes();
    _applyFilters();
    setState(() => _isLoadingPrizes = false);
  }

  void _applyFilters() {
    if (!mounted) return;

    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allPrizes.where((prize) {
      final matchesSearch =
          query.isEmpty ||
          prize.title.toLowerCase().contains(query) ||
          prize.description.toLowerCase().contains(query);

      final matchesRegion =
          _selectedRegion == PrizeCountries.all ||
          prize.countries.contains(PrizeCountries.all) ||
          prize.countries.contains(_selectedRegion);

      return matchesSearch && matchesRegion;
    }).toList();

    switch (_selectedSort) {
      case 'cost_desc':
        filtered.sort((a, b) => b.cost.compareTo(a.cost));
        break;
      case 'cost_asc':
      default:
        filtered.sort((a, b) => a.cost.compareTo(b.cost));
        break;
    }

    final normalPrizes = filtered
        .where(
          (prize) =>
              prize.type != PrizeType.reward &&
              (prize.type != PrizeType.keyed || _userHasPrizeKey(prize)),
        )
        .toList();

    final keyedPrizes = filtered
        .where(
          (prize) => prize.type == PrizeType.keyed && !_userHasPrizeKey(prize),
        )
        .toList();

    setState(() {
      _filteredPrizes = normalPrizes;
      _keyedPrizes = keyedPrizes;
    });
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
              _selectedRegion = country;
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

  void _setNewPrizes() {
    try {
      if (_showAllPrizesInNewSectionForTesting) {
        _newPrizes = List<Prize>.from(_allPrizes)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return;
      }

      _newPrizes =
          _allPrizes
              .where(
                (prize) =>
                    DateTime.now().difference(prize.createdAt).inDays <= 7 &&
                    prize.type != PrizeType.reward,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, stack) {
      AppLogger.error('Error getting prizes', e, stack);
      _newPrizes = [];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrizes();
    _detectUserCountry();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newPrizesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SharedNavigationRail(
      showAppBar: false,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.storefront),
              const SizedBox(width: 12),
              const Text('Shop'),
            ],
          ),
          automaticallyImplyLeading: false,
        ),
        body: _isLoadingPrizes
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildShopFilters(colorScheme, textTheme),
                        ),
                        const Divider(height: 1, thickness: 1),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: _buildNewPrizes(colorScheme, textTheme),
                        ),
                        const SizedBox(height: 16),
                        if (_filteredPrizes.isEmpty && _keyedPrizes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Text(
                                'No prizes found',
                                style: textTheme.bodyLarge,
                              ),
                            ),
                          )
                        else ...[
                          if (_filteredPrizes.isNotEmpty)
                            _buildPrizeGrid(
                              prizes: _filteredPrizes,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          if (_keyedPrizes.isNotEmpty) ...[
                            const Divider(height: 1, thickness: 1),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.key_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Keyed Prizes',
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPrizeGrid(
                              prizes: _keyedPrizes,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                              locked: true,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPrizeGrid({
    required List<Prize> prizes,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    bool locked = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1280
            ? 3
            : width >= 600
            ? 2
            : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 40,
            mainAxisSpacing: 40,
            childAspectRatio: 0.74,
          ),
          itemCount: prizes.length,
          itemBuilder: (context, index) => _buildPrizeCard(
            prizes[index],
            colorScheme,
            textTheme,
            isLocked: locked,
          ),
        );
      },
    );
  }

  Widget _buildShopFilters(ColorScheme colorScheme, TextTheme textTheme) {
    final dropdownIdealWidth = _regionDropdownIdealWidth(textTheme);
    const sortIdealWidth = 225.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen =
              constraints.maxWidth >=
              (320 + sortIdealWidth + dropdownIdealWidth + 48);
          final twoColumnSmall = constraints.maxWidth >= 520;

          final searchWidth = isWideScreen ? 320.0 : constraints.maxWidth;
          final splitWidth = twoColumnSmall
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          final sortWidth = isWideScreen ? sortIdealWidth : splitWidth;
          final dropdownWidth = isWideScreen ? dropdownIdealWidth : splitWidth;

          final searchField = SizedBox(
            width: searchWidth,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search prizes...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                _applyFilters();
              },
            ),
          );

          final sortDropdown = SizedBox(
            width: sortWidth,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedSort,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sort By',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'cost_asc',
                  child: Text('Cost: Ascending'),
                ),
                const DropdownMenuItem(
                  value: 'cost_desc',
                  child: Text('Cost: Descending'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedSort = value;
                });
                _applyFilters();
              },
            ),
          );

          final regionDropdown = SizedBox(
            width: dropdownWidth,
            child: DropdownButtonFormField<PrizeCountries>(
              initialValue: _selectedRegion,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Region',
                suffixIcon: _isDetectingCountry
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              selectedItemBuilder: (context) {
                return _regions
                    .map(
                      (region) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _regionLabel(region),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList();
              },
              items: _regions
                  .map(
                    (region) => DropdownMenuItem<PrizeCountries>(
                      value: region,
                      child: Text(
                        _regionLabel(region),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedRegion = value;
                });
                _applyFilters();
              },
            ),
          );

          if (isWideScreen) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                searchField,
                Row(
                  children: [
                    sortDropdown,
                    const SizedBox(width: 16),
                    regionDropdown,
                  ],
                ),
              ],
            );
          }

          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [searchField, sortDropdown, regionDropdown],
          );
        },
      ),
    );
  }

  Widget _buildNewPrizes(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoadingPrizes || _newPrizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final constrainedWidth = constraints.maxWidth > _contentMaxWidth
            ? _contentMaxWidth
            : constraints.maxWidth;
        final crossAxisCount = constrainedWidth >= 1280
            ? 3
            : constrainedWidth >= 600
            ? 2
            : 1;

        const horizontalPadding = 16.0;
        const gridSpacing = 40.0;
        const cardAspectRatio = 0.74;

        final gridContentWidth =
            constrainedWidth -
            (horizontalPadding * 2) -
            ((crossAxisCount - 1) * gridSpacing);
        final cardWidth = gridContentWidth / crossAxisCount;
        final cardHeight = cardWidth / cardAspectRatio;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                elevation: 2,
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recently Added Prizes',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _isNewPrizesCollapsed
                                ? 'Expand'
                                : 'Collapse',
                            onPressed: () {
                              setState(() {
                                _isNewPrizesCollapsed = !_isNewPrizesCollapsed;
                              });
                            },
                            icon: Icon(
                              _isNewPrizesCollapsed
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                            ),
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        firstChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check out these brand new prizes!',
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Scrollbar(
                              controller: _newPrizesScrollController,
                              thumbVisibility: true,
                              interactive: true,
                              child: SizedBox(
                                height: cardHeight,
                                child: ListView.separated(
                                  controller: _newPrizesScrollController,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _newPrizes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 24),
                                  itemBuilder: (context, index) {
                                    final prize = _newPrizes[index];
                                    return SizedBox(
                                      width: cardWidth,
                                      child: _buildPrizeCard(
                                        prize,
                                        colorScheme,
                                        textTheme,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                        crossFadeState: _isNewPrizesCollapsed
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrizeCard(
    Prize prize,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    bool isLocked = false,
  }) {
    final availableCoins = UserService.currentUser?.bootCoins.toInt() ?? 0;
    final canAfford = prize.cost <= availableCoins;

    final buttonText = isLocked
        ? 'Locked'
        : !canAfford
        ? 'Need ${prize.cost - availableCoins} more coins'
        : prize.stock <= 0
        ? 'Out of Stock'
        : 'Order Now';

    final buttonEnabled = !isLocked && canAfford && prize.stock > 0;

    final keyPrizeName = prize.key.isEmpty
        ? 'Unknown'
        : (() {
            try {
              return PrizeService.prizes
                      .cast<Prize?>()
                      .firstWhere(
                        (candidate) =>
                            (candidate?.key == prize.key) &&
                            (candidate?.type == PrizeType.reward),
                      )
                      ?.title ??
                  'Unknown';
            } catch (_) {
              return 'Unknown';
            }
          })();

    final card = InkWell(
      onTap: () {
        //TODO: Navigate to prize details page
      },
      child: Card(
        color: colorScheme.surfaceContainerLow,
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: TerminalColors.green.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 24,
                    bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: prize.picture != null && prize.picture!.isNotEmpty
                        ? Image.network(
                            prize.picture!,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Container(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: colorScheme.outline,
                              ),
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.redeem,
                              size: 40,
                              color: colorScheme.outline,
                            ),
                          ),
                  ),
                  if (_buildPrizeBadges(
                    prize,
                    colorScheme,
                    textTheme,
                  ).isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: _buildPrizeBadges(
                              prize,
                              colorScheme,
                              textTheme,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prize.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      prize.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.toll_rounded,
                          size: 18,
                          color: TerminalColors.yellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${prize.cost} coins',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: buttonEnabled
                            ? () {
                                //TODO: Navigate to prize details page
                              }
                            : null,
                        child: Text(
                          buttonText,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isLocked) {
      return card;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        IgnorePointer(child: card),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.key_rounded,
                  size: 54,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'You need the $keyPrizeName to unlock this Prize',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPrizeBadges(
    Prize prize,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final badges = <Widget>[];

    if (DateTime.now().difference(prize.createdAt).inDays <= 7) {
      badges.add(
        _buildBadge(
          label: 'NEW',
          backgroundColor: TerminalColors.green.withValues(alpha: 0.16),
          foregroundColor: TerminalColors.green,
          textTheme: textTheme,
        ),
      );
    }

    if (prize.stock <= 0) {
      badges.add(
        _buildBadge(
          label: 'Out of Stock',
          backgroundColor: TerminalColors.red.withValues(alpha: 0.16),
          foregroundColor: TerminalColors.red,
          textTheme: textTheme,
        ),
      );
    } else if (prize.stock <= 5) {
      badges.add(
        _buildBadge(
          label: '${prize.stock} Left',
          backgroundColor: TerminalColors.yellow.withValues(alpha: 0.16),
          foregroundColor: TerminalColors.yellow,
          textTheme: textTheme,
        ),
      );
    }

    if (prize.type == PrizeType.keyed) {
      badges.add(
        _buildBadge(
          label: 'Keyed',
          backgroundColor: TerminalColors.blue.withValues(alpha: 0.16),
          foregroundColor: TerminalColors.blue,
          textTheme: textTheme,
        ),
      );
    }

    return badges;
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
