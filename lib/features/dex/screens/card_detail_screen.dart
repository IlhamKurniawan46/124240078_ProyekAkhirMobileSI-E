import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/repositories/card_repository.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../converter/screens/converter_screen.dart';
import '../widgets/holo_card_widget.dart';

class CardDetailScreen extends StatefulWidget {
  final String cardId;
  final CardModel? initialCard;

  const CardDetailScreen({
    super.key,
    required this.cardId,
    this.initialCard,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  CardModel? _card;
  bool _isLoading = false;
  bool _inCollection = false;
  bool _inWatchlist = false;
  double? _alertPriceIdr;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _card = widget.initialCard;
    _initDetail();
  }

  Future<void> _initDetail() async {
    if (_card == null) {
      setState(() => _isLoading = true);
      final loaded = await CardRepository.getCardById(widget.cardId);
      if (!mounted) return;
      setState(() {
        _card = loaded;
        _isLoading = false;
      });
    }

    await _loadUserFlags();
  }

  Future<void> _loadUserFlags() async {
    final userId = AppState.instance.currentUser.value?.id;
    if (userId == null) return;

    final inCol = await CollectionRepository.isCardInCollection(
      userId,
      widget.cardId,
    );
    final watchlistItem = await CollectionRepository.getWatchlistItem(
      userId,
      widget.cardId,
    );

    if (!mounted) return;
    setState(() {
      _inCollection = inCol;
      _inWatchlist = watchlistItem != null;
      _alertPriceIdr = watchlistItem?.alertPriceIdr;
    });
  }

  Future<void> _handleWatchlistToggle() async {
    if (_isBusy) return;
    final userId = AppState.instance.currentUser.value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu.'),
          backgroundColor: AppColors.surfaceHighest,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      if (_inWatchlist) {
        await CollectionRepository.removeFromWatchlist(userId, widget.cardId);
        if (!mounted) return;
        setState(() {
          _inWatchlist = false;
          _alertPriceIdr = null;
          _isBusy = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Kartu dihapus dari Watchlist.'),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        await CollectionRepository.addToWatchlist(userId, widget.cardId);
        if (!mounted) return;
        setState(() {
          _inWatchlist = true;
          _isBusy = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.favorite, color: AppColors.pink, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kartu ditambahkan ke Watchlist!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
    }
  }

  Future<void> _showTargetPriceDialog() async {
    final userId = AppState.instance.currentUser.value?.id;
    if (userId == null) return;

    final ctrl = TextEditingController(
      text: _alertPriceIdr != null ? _alertPriceIdr!.round().toString() : '',
    );

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Target Harga Watchlist (IDR)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Harga (Rp)',
            hintText: 'Contoh: 500000',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final clean = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              final parsed = double.tryParse(clean);
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      if (!_inWatchlist) {
        await CollectionRepository.addToWatchlist(
          userId,
          widget.cardId,
          alertPriceIdr: result,
        );
      } else {
        await CollectionRepository.updateAlertPrice(
          userId,
          widget.cardId,
          result,
        );
      }
      if (!mounted) return;
      setState(() {
        _inWatchlist = true;
        _alertPriceIdr = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.surfaceHigh),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(_inWatchlist),
            ),
          ),
          title: card == null
              ? const Text('Detail Kartu')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${card.name} #${card.localId ?? card.id}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      (card.setName ?? card.setId ?? 'Pokémon TCG')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Icon(
                  _inWatchlist ? Icons.favorite : Icons.favorite_border,
                  color: _inWatchlist ? AppColors.pink : AppColors.outline,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _inWatchlist
                          ? AppColors.pink.withValues(alpha: 0.5)
                          : AppColors.surfaceHigh,
                    ),
                  ),
                ),
                tooltip: _inWatchlist
                    ? 'Hapus dari Watchlist'
                    : 'Tambah ke Watchlist',
                onPressed: _handleWatchlistToggle,
              ),
            ),
          ],
        ),
        body: _isLoading && card == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : card == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        SizedBox(height: 12),
                        Text('Kartu tidak ditemukan'),
                      ],
                    ),
                  )
                : _buildCardContent(card),
      ),
    );
  }

  Widget _buildCardContent(CardModel card) {
    final isHolo = HoloCardWidget.isHoloRarity(card.rarity);

    return ValueListenableBuilder<AppCurrency>(
      valueListenable: AppState.instance.selectedCurrency,
      builder: (context, selectedCurrency, _) {
        final convertedPrice =
            CardPriceCalculator.getConvertedPrice(card, selectedCurrency);
        final mainPriceFormatted =
            CardPriceCalculator.formatCardPrice(card, selectedCurrency);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          child: Column(
            children: [
              // 1. Stage Kartu 3D Holo Gyroscope (Terisolasi di dalam HoloCardWidget)
              HoloCardWidget(
                cardId: card.id,
                imageUrl: card.highResImageUrl ?? card.imageUrl,
                placeholderUrl: card.lowResImageUrl,
                rarity: card.rarity,
                isHolo: isHolo,
                intensity: HoloCardWidget.intensityForRarity(card.rarity),
              ),

              const SizedBox(height: 12),

              // 2. Badges Row: Rarity, Local ID, Set
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (card.rarity != null && card.rarity!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.pink.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: AppColors.pink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            card.rarity!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (card.localId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Text(
                        'No. #${card.localId}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      card.setName ?? card.setId ?? 'TCG',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Harga Pasar & Tombol Konversi Harga
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Flexible(
                              child: Text(
                                'Harga Pasar Referensi',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                selectedCurrency.code,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.surfaceHigh),
                          ),
                          child: Text(
                            card.priceSource?.toUpperCase() ?? 'TCGPLAYER',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mainPriceFormatted,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_alertPriceIdr != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Target Pengingat: ${formatIdr(_alertPriceIdr)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              foregroundColor: AppColors.gold,
                              side: const BorderSide(
                                color: AppColors.gold,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ConverterScreen(
                                    initialAmount: convertedPrice,
                                    initialCurrency: selectedCurrency.code,
                                    cardName: card.name,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.currency_exchange, size: 17),
                            label: const Text(
                              'Konversi Harga',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              foregroundColor: AppColors.pink,
                              side: BorderSide(
                                color: AppColors.pink.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _showTargetPriceDialog,
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 17,
                            ),
                            label: const Text(
                              'Target Harga',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Spesifikasi Kartu (2x2 Bento Grid)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info, color: AppColors.gold, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Detail Kartu',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'HoloDex Verified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecTile(
                            'Ekspansi / Set',
                            card.setName ?? card.setId ?? '-',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSpecTile(
                            'Nomor Kartu',
                            '#${card.localId ?? card.id}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecTile(
                            'Tipe Kartu',
                            card.cardType ?? 'Pokémon',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSpecTile(
                            'Kelangkaan',
                            card.rarity ?? 'Regular',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_inCollection) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.collections_bookmark,
                        color: AppColors.cyan,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kartu ini ada di Koleksi Saya (Diperoleh dari Pasar)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.outline),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
