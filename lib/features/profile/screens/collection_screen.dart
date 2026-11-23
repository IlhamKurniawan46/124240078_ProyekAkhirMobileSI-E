import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/database/initial_data_seeder.dart';
import '../../../core/models/card_model.dart';
import '../../../core/models/collection_item_model.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../dex/screens/card_detail_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<CollectionItemModel> _items = [];
  bool _isLoading = false;
  DateTime _lastCardTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    setState(() => _isLoading = true);
    final userId =
        AppState.instance.currentUser.value?.id ?? InitialDataSeeder.demoUserId;
    final items = await CollectionRepository.getCollectionCards(userId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _openCardDetail(CardModel? card, String fallbackCardId) {
    final now = DateTime.now();
    if (now.difference(_lastCardTap).inMilliseconds < 600) return;
    _lastCardTap = now;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(
          cardId: card?.id ?? fallbackCardId,
          initialCard: card,
        ),
      ),
    );
  }

  double? _getTotalInCurrency(AppCurrency currency) {
    double totalRefUsd = 0.0;
    for (final item in _items) {
      final refUsd = item.card?.priceRefUsd;
      if (refUsd != null && refUsd > 0) {
        totalRefUsd += refUsd;
      }
    }
    return CurrencyService.convert(
      totalRefUsd,
      from: 'USD',
      to: currency.code,
    );
  }

  int get _unpricedCount => _items
      .where((i) => i.card?.priceRefUsd == null || i.card!.priceRefUsd! <= 0)
      .length;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Koleksi Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Koleksi',
            onPressed: _isLoading ? null : _loadCollection,
          ),
        ],
      ),
      body: ValueListenableBuilder<AppCurrency>(
        valueListenable: AppState.instance.selectedCurrency,
        builder: (context, selectedCurrency, _) {
          return RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            onRefresh: _loadCollection,
            child: _isLoading && _items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _items.isEmpty
                    ? _buildEmptyView()
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildPortfolioSummary(
                              context,
                              selectedCurrency,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'DAFTAR KARTU FISIK (${_items.length})',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: AppColors.outline,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Baca-Saja',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.58,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = _items[index];
                                  return _buildCollectionCardTile(
                                    context,
                                    item.card,
                                    item.cardId,
                                    selectedCurrency,
                                  );
                                },
                                childCount: _items.length,
                              ),
                            ),
                          ),
                        ],
                      ),
          );
        },
      ),
    );
  }

  Widget _buildPortfolioSummary(
    BuildContext context,
    AppCurrency selectedCurrency,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final totalAmount = _getTotalInCurrency(selectedCurrency);
    final valueText = totalAmount != null
        ? PriceFormatter.format(totalAmount, selectedCurrency.code)
        : 'Rp0';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceHigh.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.collections_bookmark,
                color: AppColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Estimasi Nilai Koleksi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_items.length} Kartu Fisik',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Dihitung dari harga pasar TCG live',
                style: textTheme.bodySmall?.copyWith(color: AppColors.outline),
              ),
              if (_unpricedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_unpricedCount kartu tanpa data harga',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCardTile(
    BuildContext context,
    CardModel? card,
    String fallbackCardId,
    AppCurrency selectedCurrency,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final cardName = card?.name ?? 'Kartu Pokémon #$fallbackCardId';
    final cardSet = card?.setName ?? card?.setId ?? 'Pokémon TCG';
    final formattedPrice = card != null
        ? CardPriceCalculator.formatCardPrice(card, selectedCurrency)
        : '-';

    return InkWell(
      onTap: () => _openCardDetail(card, fallbackCardId),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 63 / 88,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (card?.lowResImageUrl != null)
                            CachedNetworkImage(
                              imageUrl: card!.lowResImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(
                                color: AppColors.surfaceLow,
                              ),
                              errorWidget: (ctx, url, err) => Container(
                                color: AppColors.surfaceLow,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.outline,
                                  size: 32,
                                ),
                              ),
                            )
                          else
                            Container(
                              color: AppColors.surfaceLow,
                              child: const Icon(
                                Icons.style_outlined,
                                color: AppColors.outline,
                                size: 36,
                              ),
                            ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLowest
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.cyan.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: 10,
                                    color: AppColors.cyan,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Pasar',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cyan,
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cardSet,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceHigh),
          ),
          child: const Icon(
            Icons.collections_bookmark_outlined,
            size: 40,
            color: AppColors.outline,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Koleksi Masih Kosong',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kartu masuk ke sini setelah serah terima di titik COD kamu konfirmasi di Pasar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
