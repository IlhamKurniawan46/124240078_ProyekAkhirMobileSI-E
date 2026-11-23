import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/database/initial_data_seeder.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/utils/price_formatter.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  String get _activeUserId =>
      AppState.instance.currentUser.value?.id ?? InitialDataSeeder.demoUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final list = await MarketplaceRepository.getUserTransactions(_activeUserId);
    if (!mounted) return;
    setState(() {
      _transactions = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchases = _transactions.where((t) => t.isBuyer).toList();
    final sales = _transactions.where((t) => !t.isBuyer).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(
              icon: Icon(Icons.shopping_cart_outlined, size: 20),
              text: 'Pembelian Saya',
            ),
            Tab(
              icon: Icon(Icons.sell_outlined, size: 20),
              text: 'Penjualan Saya',
            ),
          ],
        ),
      ),
      body: _isLoading && _transactions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(
                  transactions: purchases,
                  emptyTitle: 'Belum Ada Pembelian',
                  emptySubtitle:
                      'Kartu yang Anda beli dan konfirmasi di Marketplace HoloDex akan tercatat di sini dan tersimpan di Koleksi Saya.',
                  isPurchaseTab: true,
                ),
                _buildTransactionList(
                  transactions: sales,
                  emptyTitle: 'Belum Ada Penjualan',
                  emptySubtitle:
                      'Pasang listing kartu fisik Anda di Marketplace untuk mulai menjual ke sesama kolektor.',
                  isPurchaseTab: false,
                ),
              ],
            ),
    );
  }

  Widget _buildTransactionList({
    required List<TransactionModel> transactions,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isPurchaseTab,
  }) {
    if (transactions.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        onRefresh: _loadTransactions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPurchaseTab
                            ? Icons.shopping_bag_outlined
                            : Icons.storefront_outlined,
                        size: 64,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptySubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _loadTransactions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = transactions[index];
          final card = item.card;
          final dateStr = item.createdAt != null
              ? dateFormat.format(item.createdAt!.toLocal())
              : '-';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 50,
                    height: 70,
                    child: card?.lowResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.lowResImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: AppColors.surfaceHigh),
                          )
                        : Container(color: AppColors.surfaceHigh),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              card?.name ?? 'Kartu Pokémon',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SELESAI',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card?.setName ?? card?.setId ?? 'TCG'} · ${isPurchaseTab ? 'Penjual: @${item.sellerUsername ?? 'seller'}' : 'Pembeli: @${item.buyerUsername ?? 'buyer'}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            PriceFormatter.formatIdr(item.priceIdr),
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
