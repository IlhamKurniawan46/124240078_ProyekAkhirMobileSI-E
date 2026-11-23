import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/repositories/card_repository.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../converter/screens/calendar_screen.dart';
import '../../converter/screens/converter_screen.dart';
import '../widgets/card_tile.dart';
import 'card_detail_screen.dart';
import 'search_screen.dart';

/// Padding horizontal bersama untuk seluruh elemen di konten layar Dex
const double kScreenHorizontalPadding = 16.0;

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  final Set<String> _selectedCardIds = {};
  List<CardModel> _cards = [];
  SortOrder _sortOrder = SortOrder.expensiveFirst;
  bool _isLoading = false;
  bool _isSyncingApi = false;

  bool get _isSelectionMode => _selectedCardIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    await CurrencyService.initRates();
    final loaded = CardRepository.getAllCards(
      sortOrder: _sortOrder,
      onlyPriced: false,
    );
    if (!mounted) return;
    setState(() {
      _cards = loaded;
      _isLoading = false;
    });
  }

  void _setSortOrder(SortOrder newOrder) {
    if (_sortOrder == newOrder) return;
    setState(() {
      _sortOrder = newOrder;
      _cards = CardRepository.getAllCards(
        sortOrder: _sortOrder,
        onlyPriced: false,
      );
    });
  }

  Future<void> _syncFromTcgdexApi(String setId) async {
    if (_isSyncingApi) return;
    setState(() => _isSyncingApi = true);

    final syncedCount = await CardRepository.syncSetFromTcgdexApi(
      setId,
      maxNewCards: 6,
    );

    if (!mounted) return;
    setState(() {
      _isSyncingApi = false;
      _cards = CardRepository.getAllCards(
        sortOrder: _sortOrder,
        onlyPriced: false,
      );
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          syncedCount > 0
              ? 'Berhasil menyinkronkan $syncedCount kartu dari TCGdex REST API ($setId)!'
              : 'Katalog lokal siap digunakan (${_cards.length} kartu di Hive).',
        ),
        backgroundColor: AppColors.surfaceHighest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTcgdexSyncDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync, color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sinkronkan Katalog (TCGdex REST API)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih set ekspansi untuk ditarik langsung melalui HTTP GET ke api.tcgdex.net dan disimpan ke Hive Box:',
                  style: TextStyle(fontSize: 12, color: AppColors.outline),
                ),
                const SizedBox(height: 16),
                ...CardRepository.targetSets.map((s) {
                  final setId = s['id']!;
                  final setName = s['name']!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceHigh),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.catching_pokemon, color: AppColors.gold),
                      title: Text(
                        setName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'GET /v2/en/sets/$setId',
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      ),
                      trailing: const Icon(Icons.download, color: AppColors.gold, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        _syncFromTcgdexApi(setId);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleCardSelection(String cardId) {
    setState(() {
      if (_selectedCardIds.contains(cardId)) {
        _selectedCardIds.remove(cardId);
      } else {
        _selectedCardIds.add(cardId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedCardIds.clear();
    });
  }

  Future<void> _addSelectedToWatchlist() async {
    final userId = AppState.instance.currentUser.value?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu.'),
          backgroundColor: AppColors.surfaceHighest,
        ),
      );
      return;
    }

    final totalSelected = _selectedCardIds.length;
    final addedCount = await CollectionRepository.addMultipleToWatchlist(
      userId,
      _selectedCardIds.toList(),
    );
    final alreadyCount = totalSelected - addedCount;

    if (!mounted) return;
    _exitSelectionMode();

    final message = addedCount > 0
        ? '$addedCount kartu ditambahkan ke Watchlist${alreadyCount > 0 ? ' ($alreadyCount sudah ada)' : ''}'
        : 'Semua kartu yang dipilih sudah ada di Watchlist';

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.pink, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.surfaceHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showTotalPriceBottomSheet(BuildContext context) {
    final selectedCards =
        _cards.where((c) => _selectedCardIds.contains(c.id)).toList();
    final selectedCurrency = AppState.instance.selectedCurrency.value;

    double totalRefUsd = 0.0;
    int pricedCount = 0;
    for (final card in selectedCards) {
      if (card.priceRefUsd != null && card.priceRefUsd! > 0) {
        totalRefUsd += card.priceRefUsd!;
        pricedCount++;
      }
    }
    final unpricedCount = selectedCards.length - pricedCount;

    final totalConverted = CurrencyService.convert(
      totalRefUsd,
      from: 'USD',
      to: selectedCurrency.code,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate, color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Total Harga (${selectedCards.length} Kartu)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi Total Harga Pilihan:',
                        style: TextStyle(fontSize: 12, color: AppColors.outline),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalConverted != null
                            ? PriceFormatter.format(
                                totalConverted,
                                selectedCurrency.code,
                              )
                            : 'Kurs belum siap',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                      if (unpricedCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$unpricedCount kartu tanpa data harga pasar tidak dihitung.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kartu Terpilih:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: selectedCards.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: AppColors.surfaceHigh,
                    ),
                    itemBuilder: (context, idx) {
                      final card = selectedCards[idx];
                      final priceText = CardPriceCalculator.formatCardPrice(
                        card,
                        selectedCurrency,
                      );
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          card.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          card.setName ?? 'Pokémon TCG',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.outline,
                          ),
                        ),
                        trailing: Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.onGold,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sort, color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Pengurutan & Filter Katalog',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih urutan tampilan kartu di katalog Dex:',
                  style: TextStyle(fontSize: 12, color: AppColors.outline),
                ),
                const SizedBox(height: 16),
                ...SortOrder.values.map((order) {
                  final isSelected = _sortOrder == order;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.gold : AppColors.surfaceHigh,
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: Icon(
                        order == SortOrder.expensiveFirst
                            ? Icons.trending_up
                            : (order == SortOrder.cheapestFirst
                                ? Icons.trending_down
                                : Icons.sort_by_alpha),
                        color: isSelected ? AppColors.gold : AppColors.outline,
                        size: 22,
                      ),
                      title: Text(
                        order.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        order.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.gold,
                              size: 20,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked,
                              color: AppColors.surfaceHighest,
                              size: 20,
                            ),
                      onTap: () {
                        _setSortOrder(order);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceHigh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(
                      Icons.tune,
                      color: AppColors.gold,
                      size: 18,
                    ),
                    label: const Text(
                      'Buka Filter Lanjutan (Set, Rarity, Harga)',
                      style: TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: _isSelectionMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Batal Pilih',
                  onPressed: _exitSelectionMode,
                ),
                title: Text(
                  '${_selectedCardIds.length} dipilih',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.favorite_border,
                      color: AppColors.pink,
                    ),
                    tooltip: 'Tambah ke Watchlist',
                    onPressed: _addSelectedToWatchlist,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.calculate_outlined,
                      color: AppColors.gold,
                    ),
                    tooltip: 'Total Harga',
                    onPressed: () => _showTotalPriceBottomSheet(context),
                  ),
                ],
              )
            : AppBar(
                title: Image.asset(
                  'assets/images/logo.png',
                  height: 22,
                  fit: BoxFit.contain,
                ),
                actions: [
                  IconButton(
                    tooltip: 'Sinkronkan dari TCGdex API',
                    icon: _isSyncingApi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          )
                        : const Icon(
                            Icons.cloud_sync_outlined,
                            color: AppColors.gold,
                          ),
                    onPressed: _isSyncingApi ? null : _showTcgdexSyncDialog,
                  ),
                ],
              ),
        body: ValueListenableBuilder<AppCurrency>(
          valueListenable: AppState.instance.selectedCurrency,
          builder: (context, selectedCurrency, _) {
            return Column(
              children: [
                // Bar Pencarian & Filter Cepat
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kScreenHorizontalPadding,
                    12,
                    kScreenHorizontalPadding,
                    4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceHigh),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SearchScreen(),
                                ),
                              );
                            },
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: AppColors.outline,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Cari nama kartu, set, atau kelangkaan...',
                                      style: TextStyle(
                                        color: AppColors.outline,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showSortFilterBottomSheet(context),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 16,
                                  width: 1,
                                  color: AppColors.surfaceHigh,
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.tune,
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isSelectionMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: AppColors.gold.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.touch_app,
                          size: 16,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ketuk kartu untuk memilih/batal. Pilih ikon Watchlist atau Total Harga di atas.',
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppColors.goldSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: _buildBody(selectedCurrency, textTheme),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(AppCurrency selectedCurrency, TextTheme textTheme) {
    final textScaler = MediaQuery.textScalerOf(context);
    final isLargeText = textScaler.scale(10) > 11.5;
    final cardAspectRatio = isLargeText ? 0.465 : 0.505;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: _loadCatalog,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. Baris Utilitas: 2 Tile Berlabel (Event & Konverter)
          if (!_isSelectionMode)
            SliverToBoxAdapter(
              child: _buildFeatureTiles(context),
            ),

          // 2. Header Katalog & Selector Mata Uang Kompak
          _buildCatalogHeader(context, selectedCurrency, textTheme),

          // 3. Grid Kartu Katalog
          if (_isLoading && _cards.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                kScreenHorizontalPadding,
                4,
                kScreenHorizontalPadding,
                24,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: cardAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final card = _cards[index];
                    final isSelected = _selectedCardIds.contains(card.id);

                    return CardTile(
                      card: card,
                      isSelected: isSelected,
                      isSelectionMode: _isSelectionMode,
                      onLongPress: () => _toggleCardSelection(card.id),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleCardSelection(card.id);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CardDetailScreen(
                                cardId: card.id,
                                initialCard: card,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                  childCount: _cards.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCatalogHeader(
    BuildContext context,
    AppCurrency selectedCurrency,
    TextTheme textTheme,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kScreenHorizontalPadding,
          10,
          kScreenHorizontalPadding,
          8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScaler = MediaQuery.textScalerOf(context);
            final estimatedTitleWidth = textScaler.scale(90.0);
            final estimatedChipsWidth =
                AppCurrency.values.length * textScaler.scale(42.0) +
                    (AppCurrency.values.length - 1) * 5.0;
            final isSingleLine = constraints.maxWidth >=
                (estimatedTitleWidth + estimatedChipsWidth + 10.0);

            final titleWidget = Semantics(
              header: true,
              child: Text(
                'Katalog',
                maxLines: 1,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            );

            if (isSingleLine) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: titleWidget,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCompactCurrencyChips(selectedCurrency),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: titleWidget,
                  ),
                  const SizedBox(height: 8),
                  _buildExpandedCurrencyChips(selectedCurrency),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCompactCurrencyChips(AppCurrency selectedCurrency) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: AppCurrency.values.map((currency) {
        final isSelected = selectedCurrency == currency;
        return Padding(
          padding: const EdgeInsets.only(left: 5),
          child: _buildCurrencyChipItem(currency, isSelected),
        );
      }).toList(),
    );
  }

  Widget _buildExpandedCurrencyChips(AppCurrency selectedCurrency) {
    return Row(
      children: AppCurrency.values.map((currency) {
        final isSelected = selectedCurrency == currency;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: _buildCurrencyChipItem(
              currency,
              isSelected,
              isExpanded: true,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurrencyChipItem(
    AppCurrency currency,
    bool isSelected, {
    bool isExpanded = false,
  }) {
    return Semantics(
      button: true,
      label: 'Pilih mata uang ${currency.code}',
      selected: isSelected,
      child: ChoiceChip(
        label: isExpanded
            ? Center(
                child: Text(
                  currency.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : SizedBox(
                width: 34,
                child: Center(
                  child: Text(
                    currency.code,
                    maxLines: 1,
                  ),
                ),
              ),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) {
          AppState.instance.setCurrency(currency);
        },
        selectedColor: AppColors.gold,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isSelected ? AppColors.onGold : AppColors.onSurfaceVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        labelPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// Baris Fitur: 2 Tile Berlabel (Event & Konverter) sesuai spesifikasi HoloDex v2
  Widget _buildFeatureTiles(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kScreenHorizontalPadding,
        4,
        kScreenHorizontalPadding,
        8,
      ),
      child: Row(
        children: [
          _buildSingleFeatureTile(
            context: context,
            label: 'Event & Pengingat',
            icon: Icons.calendar_month,
            semanticsLabel: 'Menu Event dan Pengingat Pokémon',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildSingleFeatureTile(
            context: context,
            label: 'Konverter Kurs',
            icon: Icons.currency_exchange,
            semanticsLabel: 'Menu Konverter Mata Uang',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConverterScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSingleFeatureTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String semanticsLabel,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
