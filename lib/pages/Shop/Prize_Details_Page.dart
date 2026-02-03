import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/services/prizes/Prize.dart';
import '/services/users/User.dart';
import '/services/notifications/notifications.dart';
import '/widgets/shared_navigation_rail.dart';

class PrizeDetailsPage extends StatefulWidget {
  final Prize prize;
  final bool isInCart;
  final int currentQuantity;
  final Function(String, int) onAddToCart;

  const PrizeDetailsPage({
    super.key,
    required this.prize,
    required this.isInCart,
    required this.currentQuantity,
    required this.onAddToCart,
  });

  @override
  State<PrizeDetailsPage> createState() => _PrizeDetailsPageState();
}

class _PrizeDetailsPageState extends State<PrizeDetailsPage> {
  late int _quantity;
  late int _grantAmount;

  @override
  void initState() {
    super.initState();
    _quantity = widget.currentQuantity > 0 ? widget.currentQuantity : 1;
    _grantAmount = widget.prize.type == PrizeType.grant ? 10 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isOutOfStock = widget.prize.stock <= 0;
    final bool isGrant = widget.prize.type == PrizeType.grant;
    final bool isLowStock = widget.prize.stock > 0 && widget.prize.stock <= 5;

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
                icon: const Icon(Symbols.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Icon(Symbols.storefront, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Shop'),
            ],
          ),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;
                  if (isMobile) {
                    return _buildMobileLayout(
                      colorScheme,
                      textTheme,
                      isOutOfStock,
                      isGrant,
                      isLowStock,
                    );
                  } else {
                    return _buildDesktopLayout(
                      colorScheme,
                      textTheme,
                      isOutOfStock,
                      isGrant,
                      isLowStock,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isOutOfStock,
    bool isGrant,
    bool isLowStock,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImage(colorScheme),
          const SizedBox(height: 24),
          _buildProductInfo(
            colorScheme,
            textTheme,
            isOutOfStock,
            isGrant,
            isLowStock,
          ),
          const SizedBox(height: 24),
          _buildPurchaseBox(
            colorScheme,
            textTheme,
            isOutOfStock,
            isGrant,
            isLowStock,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isOutOfStock,
    bool isGrant,
    bool isLowStock,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Image
          Expanded(flex: 4, child: _buildImage(colorScheme)),
          const SizedBox(width: 24),
          // Middle: Product Info
          Expanded(
            flex: 5,
            child: _buildProductInfo(
              colorScheme,
              textTheme,
              isOutOfStock,
              isGrant,
              isLowStock,
            ),
          ),
          const SizedBox(width: 24),
          // Right: Purchase Box
          SizedBox(
            width: 320,
            child: _buildPurchaseBox(
              colorScheme,
              textTheme,
              isOutOfStock,
              isGrant,
              isLowStock,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: widget.prize.picture != null && widget.prize.picture!.isNotEmpty
            ? Image.network(
                widget.prize.picture!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    Symbols.redeem,
                    size: 120,
                    color: colorScheme.outline,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Symbols.redeem,
                  size: 120,
                  color: colorScheme.outline,
                ),
              ),
      ),
    );
  }

  Widget _buildProductInfo(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isOutOfStock,
    bool isGrant,
    bool isLowStock,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.prize.title,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        // Price/Cost
        if (!isGrant)
          Row(
            children: [
              Icon(Symbols.toll, size: 28, color: TerminalColors.yellow),
              const SizedBox(width: 8),
              Text(
                '${widget.prize.cost}',
                style: textTheme.headlineLarge?.copyWith(
                  color: TerminalColors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'coins',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

        if (isGrant)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TerminalColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: TerminalColors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.volunteer_activism,
                  size: 24,
                  color: TerminalColors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Grant Prize',
                  style: textTheme.titleMedium?.copyWith(
                    color: TerminalColors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Stock status
        Row(
          children: [
            Icon(
              Symbols.inventory_2,
              size: 20,
              color: isOutOfStock
                  ? TerminalColors.red
                  : isLowStock
                  ? TerminalColors.yellow
                  : TerminalColors.green,
            ),
            const SizedBox(width: 8),
            Text(
              isOutOfStock
                  ? 'Out of Stock'
                  : isLowStock
                  ? 'Only ${widget.prize.stock} left in stock'
                  : 'In Stock (${widget.prize.stock} available)',
              style: textTheme.titleMedium?.copyWith(
                color: isOutOfStock
                    ? TerminalColors.red
                    : isLowStock
                    ? TerminalColors.yellow
                    : TerminalColors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Divider(color: colorScheme.outline.withValues(alpha: 0.3)),
        const SizedBox(height: 24),

        // Description
        Text(
          'About this prize',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          widget.prize.description,
          style: textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: colorScheme.onSurface,
          ),
        ),

        // Specs
        if (widget.prize.specs.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Product Details',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              widget.prize.specs,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],

        // Available Countries
        if (widget.prize.countries.isNotEmpty &&
            !widget.prize.countries.contains(PrizeCountries.all)) ...[
          const SizedBox(height: 24),
          Text(
            'Ships to',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.prize.countries.map((country) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _getCountryName(country),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPurchaseBox(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isOutOfStock,
    bool isGrant,
    bool isLowStock,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Price Summary
          if (!isGrant) ...[
            Row(
              children: [
                Icon(Symbols.toll, size: 32, color: TerminalColors.yellow),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.prize.cost}',
                      style: textTheme.headlineMedium?.copyWith(
                        color: TerminalColors.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'coins each',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  String _getCountryName(PrizeCountries country) {
    final countryNames = {
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
