import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/database/initial_data_seeder.dart';
import '../../../core/models/card_model.dart';
import '../../../core/models/watchlist_item_model.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../dex/screens/card_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  /// Helper murni untuk mengevaluasi apakah harga pasar live kartu <= target harga.
  static bool isTargetReached(WatchlistItemModel item) {
    final targetIdr = item.alertPriceIdr;
    final card = item.card;
    if (targetIdr == null || targetIdr <= 0 || card == null) return false;

    final liveIdr =
        CardPriceCalculator.getConvertedPrice(card, AppCurrency.idr) ??
            card.priceIdr;
    if (liveIdr == null || liveIdr <= 0) return false;
    return liveIdr <= targetIdr;
  }

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<WatchlistItemModel> _items = [];
  bool _isLoading = false;
  DateTime _lastCardTap = DateTime.fromMillisecondsSinceEpoch(0);

  String get _activeUserId =>
      AppState.instance.currentUser.value?.id ?? InitialDataSeeder.demoUserId;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() => _isLoading = true);
    final items = await CollectionRepository.getWatchlist(_activeUserId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _openCardDetail(CardModel? card, String cardId) async {
    final now = DateTime.now();
    if (now.difference(_lastCardTap).inMilliseconds < 600) return;
    _lastCardTap = now;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(
          cardId: cardId,
          initialCard: card,
        ),
      ),
    );
    if (mounted) _loadWatchlist();
  }

  void _showSetTargetDialog(WatchlistItemModel item) {
    final selectedCurrency = AppState.instance.selectedCurrency.value;
    final controller = TextEditingController();

    if (item.alertPriceIdr != null && item.alertPriceIdr! > 0) {
      final converted = CurrencyService.convert(
        item.alertPriceIdr!,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      if (converted != null) {
        controller.text = (selectedCurrency == AppCurrency.idr ||
                selectedCurrency == AppCurrency.jpy)
            ? converted.round().toString()
            : converted.toStringAsFixed(2);
      }
    }

    final cardName = item.card?.name ?? 'Kartu Pokémon';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.price_change, color: AppColors.gold, size: 22),
            SizedBox(width: 8),
            Text('Atur Target Harga', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tentukan target harga untuk $cardName dalam ${selectedCurrency.code}. '
              'Lencana "Target Tercapai" muncul bila harga pasar <= target ini.',
              style: const TextStyle(fontSize: 12, color: AppColors.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '${selectedCurrency.symbol} ',
                labelText: 'Harga Target (${selectedCurrency.code})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (item.alertPriceIdr != null)
            TextButton(
              onPressed: () async {
                await CollectionRepository.updateAlertPrice(
                  _activeUserId,
                  item.cardId,
                  null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadWatchlist();
              },
              child: const Text(
                'Hapus Target',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onGold,
            ),
            onPressed: () async {
              final rawText = controller.text.trim().replaceAll(',', '.');
              final inputAmount = double.tryParse(rawText);
              if (inputAmount != null && inputAmount > 0) {
                final idrAmount = CurrencyService.convert(
                  inputAmount,
                  from: selectedCurrency.code,
                  to: 'IDR',
                );
                await CollectionRepository.updateAlertPrice(
                  _activeUserId,
                  item.cardId,
                  idrAmount,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadWatchlist();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeItem(WatchlistItemModel item) async {
    final cardName = item.card?.name ?? 'Kartu';
    await CollectionRepository.removeFromWatchlist(_activeUserId, item.cardId);
    if (!mounted) return;
    _loadWatchlist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$cardName dihapus dari Watchlist.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(WatchlistItemModel item) {
    final cardName = item.card?.name ?? 'kartu ini';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus dari Watchlist?'),
        content: Text('Hapus $cardName dari daftar pantauan kamu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceLowest,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _removeItem(item);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Watchlist & Target Harga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadWatchlist,
          ),
        ],
      ),
      body: ValueListenableBuilder<AppCurrency>(
        valueListenable: AppState.instance.selectedCurrency,
        builder: (context, selectedCurrency, _) {
          return RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            onRefresh: _loadWatchlist,
            child: _isLoading && _items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _items.isEmpty
                    ? _buildEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildWatchlistTile(
                            context,
                            item,
                            selectedCurrency,
                            textTheme,
                          );
                        },
                      ),
          );
        },
      ),
    );
  }

  Widget _buildWatchlistTile(
    BuildContext context,
    WatchlistItemModel item,
    AppCurrency selectedCurrency,
    TextTheme textTheme,
  ) {
    final card = item.card;
    final cardName = card?.name ?? 'Kartu Pokémon #${item.cardId}';
    final cardSet = card?.setName ?? card?.setId ?? 'Pokémon TCG';
    final currentPriceFormatted = card != null
        ? CardPriceCalculator.formatCardPrice(card, selectedCurrency)
        : '-';

    final targetReached = WatchlistScreen.isTargetReached(item);

    String? targetPriceFormatted;
    if (item.alertPriceIdr != null && item.alertPriceIdr! > 0) {
      final converted = CurrencyService.convert(
        item.alertPriceIdr!,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      if (converted != null) {
        targetPriceFormatted =
            PriceFormatter.format(converted, selectedCurrency.code);
      }
    }

    return Dismissible(
      key: Key('watchlist_${item.cardId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: targetReached
                ? AppColors.success.withValues(alpha: 0.6)
                : AppColors.surfaceHigh,
          ),
        ),
        child: InkWell(
          onTap: () => _openCardDetail(card, card?.id ?? item.cardId),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 52,
                    height: 72,
                    child: card?.lowResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.lowResImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => Container(
                              color: AppColors.surfaceLow,
                            ),
                            errorWidget: (ctx, url, error) => Container(
                              color: AppColors.surfaceLow,
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceLow,
                            child: const Icon(Icons.style, size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cardName,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (targetReached) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      AppColors.success.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 11,
                                    color: AppColors.success,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Target Tercapai',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Sekarang: $currentPriceFormatted',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                          if (targetPriceFormatted != null)
                            Text(
                              'Target: $targetPriceFormatted',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: targetReached
                                    ? AppColors.success
                                    : AppColors.outline,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.outline),
                  color: AppColors.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'target') {
                      _showSetTargetDialog(item);
                    } else if (value == 'delete') {
                      _confirmDelete(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'target',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.price_change,
                            size: 18,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.alertPriceIdr != null
                                ? 'Ubah Target Harga'
                                : 'Set Target Harga',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Hapus dari Watchlist',
                            style: TextStyle(color: AppColors.error),
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
            Icons.favorite_border,
            size: 40,
            color: AppColors.pink,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Watchlist Masih Kosong',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pantau kartu favorit dan pasang harga target lewat ikon hati di detail kartu atau mode pilih di Dex.',
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
