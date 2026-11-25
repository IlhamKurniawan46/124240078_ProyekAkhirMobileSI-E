import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/database/initial_data_seeder.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../widgets/listing_card.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'map_screen.dart';
import 'my_orders_screen.dart';
import 'transaction_history_screen.dart';

enum MarketplaceSort {
  newest('Terbaru'),
  cheapest('Harga Termurah'),
  priciest('Harga Termahal');

  final String label;
  const MarketplaceSort(this.label);
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedSegment = 0; // 0: Listing Marketplace, 1: Pesanan Saya
  int _orderSubTab = 0; // 0: Pembelian, 1: Penjualan

  List<ListingModel> _listings = [];
  List<OrderModel> _orders = [];
  String _searchQuery = '';
  String _selectedCondition = 'all';
  MarketplaceSort _sortBy = MarketplaceSort.newest;
  bool _isLoading = false;

  String get _activeUserId =>
      AppState.instance.currentUser.value?.id ?? InitialDataSeeder.demoUserId;

  List<OrderModel> get _buyerOrders =>
      _orders.where((o) => o.buyerId == _activeUserId).toList();

  List<OrderModel> get _sellerOrders =>
      _orders.where((o) => o.sellerId == _activeUserId).toList();

  int get _actionRequiredCount =>
      _orders.where((o) => o.isReserved && !o.isExpired()).length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await AuthService.refreshCurrentUser();
    final listings = await MarketplaceRepository.fetchActiveListings();
    final orders = await OrderRepository.getMyOrders(_activeUserId);
    if (!mounted) return;
    setState(() {
      _listings = listings;
      _orders = orders;
      _isLoading = false;
    });
  }

  List<ListingModel> get _filteredListings {
    final q = _searchQuery.trim().toLowerCase();
    final list = _listings.where((l) {
      if (_selectedCondition != 'all' &&
          l.condition.toLowerCase() != _selectedCondition.toLowerCase()) {
        return false;
      }
      if (q.isNotEmpty) {
        final cardName = (l.card?.name ?? '').toLowerCase();
        final setName = (l.card?.setName ?? '').toLowerCase();
        final sellerName = (l.sellerUsername ?? '').toLowerCase();
        if (!cardName.contains(q) &&
            !setName.contains(q) &&
            !sellerName.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case MarketplaceSort.newest:
        list.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        break;
      case MarketplaceSort.cheapest:
        list.sort((a, b) => a.priceIdr.compareTo(b.priceIdr));
        break;
      case MarketplaceSort.priciest:
        list.sort((a, b) => b.priceIdr.compareTo(a.priceIdr));
        break;
    }
    return list;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCondition = 'all';
      _sortBy = MarketplaceSort.newest;
    });
  }

  void _showTopUpDialog(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.gold,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Top Up Saldo Virtual',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tambahkan saldo untuk berbelanja kartu di marketplace.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildTopUpOption(ctx, userId, 250000, '+ Rp250.000'),
                    _buildTopUpOption(ctx, userId, 500000, '+ Rp500.000'),
                    _buildTopUpOption(ctx, userId, 1000000, '+ Rp1.000.000'),
                    _buildTopUpOption(ctx, userId, 2500000, '+ Rp2.500.000'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopUpOption(
    BuildContext context,
    String userId,
    double amount,
    String label,
  ) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        try {
          final newBalance = await MarketplaceRepository.topUpBalance(
            userId: userId,
            amount: amount,
          );
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Saldo berhasil ditambah! Saldo saat ini: ${PriceFormatter.formatIdr(newBalance)}',
                ),
                backgroundColor: AppColors.snackBarSuccess,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Gagal top up: $e'),
                backgroundColor: AppColors.snackBarError,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showSortFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Urutkan & Saring',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        _resetFilters();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: AppColors.gold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Urutkan Berdasarkan:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MarketplaceSort.values.map((sortOption) {
                    return ChoiceChip(
                      label: Text(sortOption.label),
                      selected: _sortBy == sortOption,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _sortBy = sortOption);
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _openListingDetail(ListingModel listing) async {
    final currentUserId = AppState.instance.currentUser.value?.id;
    if (listing.isReserved &&
        currentUserId != null &&
        listing.sellerId == currentUserId) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MyOrdersScreen(initialTabIndex: 1),
        ),
      );
      if (mounted) {
        await _loadData();
      }
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(
          listingId: listing.id,
          initialListing: listing,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filteredListings = _filteredListings;
    final actionCount = _actionRequiredCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Marketplace',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppColors.gold),
            tooltip: 'Peta Penjual Terdekat (LBS)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.onSurfaceVariant),
            tooltip: 'Riwayat Transaksi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _selectedSegment == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              elevation: 4,
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: const Text(
                'Jual Kartu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: _openCreateListing,
            )
          : null,
      body: ValueListenableBuilder<UserModel?>(
        valueListenable: AppState.instance.currentUser,
        builder: (context, user, _) {
          return RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Banner Saldo & Top Up Virtual
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.surfaceHigh, AppColors.surface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.gold.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        spacing: 12,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Saldo HoloPay (Simulasi)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  PriceFormatter.formatIdr(
                                    user?.balanceIdr ?? 0,
                                  ),
                                  style: textTheme.titleMedium?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (user != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.gold.withAlpha(26),
                                foregroundColor: AppColors.gold,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () =>
                                  _showTopUpDialog(context, user.id),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Top Up',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Kontrol Segmen: Listing Marketplace | Pesanan Saya
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.withAlpha(120),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: () {
                                if (_selectedSegment != 0) {
                                  setState(() => _selectedSegment = 0);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedSegment == 0
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Listing Marketplace',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _selectedSegment == 0
                                          ? Colors.black
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: () {
                                if (_selectedSegment != 1) {
                                  setState(() => _selectedSegment = 1);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedSegment == 1
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Pesanan Saya',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: _selectedSegment == 1
                                              ? Colors.black
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      if (actionCount > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _selectedSegment == 1
                                                ? Colors.black
                                                : AppColors.gold,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$actionCount',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: _selectedSegment == 1
                                                  ? AppColors.gold
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_selectedSegment == 0) ...[
                  // Search Bar & Filter Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Cari kartu Pokémon / penjual...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.surfaceHigh,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.surfaceHigh,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.surfaceHigh),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.map_outlined,
                                color: AppColors.gold,
                              ),
                              tooltip: 'Peta Penjual Terdekat (LBS)',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MapScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.surfaceHigh),
                            ),
                            child: IconButton(
                              icon:
                                  const Icon(Icons.tune, color: AppColors.gold),
                              tooltip: 'Urutkan & Saring',
                              onPressed: () => _showSortFilterModal(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Baris Filter Kondisi Kartu
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _buildConditionChip('all', 'Semua'),
                          const SizedBox(width: 8),
                          _buildConditionChip('mint', 'Mint (Mulus)'),
                          const SizedBox(width: 8),
                          _buildConditionChip('near_mint', 'Near Mint'),
                          const SizedBox(width: 8),
                          _buildConditionChip('excellent', 'Excellent'),
                          const SizedBox(width: 8),
                          _buildConditionChip('good', 'Good'),
                          const SizedBox(width: 8),
                          _buildConditionChip('poor', 'Poor'),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 8),
                  ),

                  if (_isLoading && _listings.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    )
                  else if (filteredListings.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.store_mall_directory_outlined,
                                size: 64,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum Ada Kartu Dijual',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedCondition != 'all'
                                    ? 'Tidak ada kartu yang cocok dengan saringan saat ini. Coba reset filter.'
                                    : 'Jadilah yang pertama memasang listing kartu fisik di Marketplace HoloDex!',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_searchQuery.isNotEmpty ||
                                  _selectedCondition != 'all')
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.gold,
                                    side: const BorderSide(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Reset Saringan'),
                                  onPressed: _resetFilters,
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: Colors.black,
                                  ),
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 16,
                                  ),
                                  label: const Text('Jual Kartu Pertama'),
                                  onPressed: _openCreateListing,
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.60,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final listing = filteredListings[index];
                            return ListingCard(
                              listing: listing,
                              onTap: () => _openListingDetail(listing),
                            );
                          },
                          childCount: filteredListings.length,
                        ),
                      ),
                    ),
                ] else ...[
                  _buildOrdersSegmentSliver(context, textTheme),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: 88),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersSegmentSliver(
    BuildContext context,
    TextTheme textTheme,
  ) {
    final isBuyerSubTab = _orderSubTab == 0;
    final buyerOrders = _buyerOrders;
    final sellerOrders = _sellerOrders;
    final orders = isBuyerSubTab ? buyerOrders : sellerOrders;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        'Pembelian (${buyerOrders.length})',
                        style: TextStyle(
                          color: _orderSubTab == 0
                              ? Colors.black
                              : AppColors.onSurface,
                          fontWeight: _orderSubTab == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    selected: _orderSubTab == 0,
                    showCheckmark: false,
                    selectedColor: AppColors.gold,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _orderSubTab == 0
                            ? AppColors.gold
                            : AppColors.surfaceHigh,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _orderSubTab = 0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        'Penjualan (${sellerOrders.length})',
                        style: TextStyle(
                          color: _orderSubTab == 1
                              ? Colors.black
                              : AppColors.onSurface,
                          fontWeight: _orderSubTab == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    selected: _orderSubTab == 1,
                    showCheckmark: false,
                    selectedColor: AppColors.gold,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _orderSubTab == 1
                            ? AppColors.gold
                            : AppColors.surfaceHigh,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _orderSubTab = 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading && _orders.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
          )
        else if (orders.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBuyerSubTab
                        ? Icons.shopping_bag_outlined
                        : Icons.storefront_outlined,
                    size: 44,
                    color: AppColors.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isBuyerSubTab
                        ? 'Belum ada pesanan pembelian aktif.\nPilih kartu yang kamu minati di Listing Marketplace!'
                        : 'Belum ada pesanan penjualan aktif.\nPasang listing menarik untuk kolektor lain!',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = orders[index];
                  return OrderCardItem(
                    order: order,
                    isBuyer: isBuyerSubTab,
                    onOrderChanged: _loadData,
                  );
                },
                childCount: orders.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConditionChip(String conditionKey, String label) {
    final isSelected = _selectedCondition == conditionKey;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.gold,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedCondition = conditionKey);
        }
      },
    );
  }
}
