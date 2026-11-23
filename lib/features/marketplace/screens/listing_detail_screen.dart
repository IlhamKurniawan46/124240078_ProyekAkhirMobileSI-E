import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../profile/widgets/whatsapp_dialog.dart';
import 'create_listing_screen.dart';
import 'map_screen.dart';
import 'my_orders_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  final ListingModel? initialListing;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  ListingModel? _listing;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPurchasing = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _listing = widget.initialListing;
    if (_listing == null) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail =
          await MarketplaceRepository.getListingDetail(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = detail;
        _isLoading = false;
        if (detail == null) {
          _errorMessage = 'Listing tidak ditemukan atau telah dihapus.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat detail listing: $e';
      });
    }
  }

  /// Buka form Edit Listing (Update CRUD) dan segarkan detail saat kembali
  Future<void> _handleEditListing() async {
    final listing = _listing;
    if (listing == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateListingScreen(existingListing: listing),
      ),
    );

    if (updated == true && mounted) {
      _hasChanged = true;
      await _loadDetail();
    }
  }

  Future<void> _handleBuy() async {
    final user = AppState.instance.currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu untuk memesan kartu.'),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final listing = _listing;
    if (listing == null) return;

    // Pengecekan Just-in-Time: Pembeli wajib memiliki nomor WhatsApp
    if (user.whatsappNumber == null || user.whatsappNumber!.trim().isEmpty) {
      final savedPhone = await WhatsAppDialog.show(
        context,
        customTitle: 'Nomor WhatsApp Pembeli',
        customExplanation:
            'Nomor WhatsApp diperlukan agar penjual dapat menghubungi kamu untuk koordinasi serah terima COD.',
      );

      if (savedPhone == null || savedPhone.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pemesanan dibatalkan: Nomor WhatsApp wajib diisi untuk koordinasi COD.',
              ),
              backgroundColor: AppColors.surfaceHigh,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final latestUser = AppState.instance.currentUser.value ?? user;

    if (latestUser.balanceIdr < listing.priceIdr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo Anda tidak mencukupi untuk memesan kartu ini.'),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedCurrency = AppState.instance.selectedCurrency.value;
    String displayPrice;
    if (selectedCurrency == AppCurrency.idr) {
      displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
    } else {
      final converted = CurrencyService.convert(
        listing.priceIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      displayPrice = converted != null
          ? PriceFormatter.format(converted, selectedCurrency.code)
          : PriceFormatter.formatIdr(listing.priceIdr);
    }

    final remainingBalance = latestUser.balanceIdr - listing.priceIdr;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lock_clock,
                      color: AppColors.gold,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pesan Kartu (Rekber COD)',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kartu:'),
                          Flexible(
                            child: Text(
                              listing.card?.name ?? 'Kartu Pokémon',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kondisi:'),
                          Text(
                            listing.conditionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Penjual:'),
                          Text('@${listing.sellerUsername ?? 'Penjual'}'),
                        ],
                      ),
                      if (listing.lat != null && listing.lng != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Titik COD:'),
                            Flexible(
                              child: Text(
                                '${listing.lat!.toStringAsFixed(4)}, ${listing.lng!.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Harga Kartu:'),
                          Text(
                            selectedCurrency == AppCurrency.idr
                                ? displayPrice
                                : '$displayPrice (${PriceFormatter.formatIdr(listing.priceIdr)})',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Saldo Setelah Ditahan:'),
                          Text(
                            PriceFormatter.formatIdr(remainingBalance),
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saldo ditahan sampai kamu mengonfirmasi kartu diterima. Pesanan otomatis batal dalam 72 jam bila tidak ada konfirmasi.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.onGold,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Pesan Sekarang',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isPurchasing = true);

    try {
      await OrderRepository.reserveListing(
        listingId: listing.id,
        buyerId: latestUser.id,
      );

      if (!mounted) return;
      _hasChanged = true;
      setState(() {
        _isPurchasing = false;
        _listing = _listing?.copyWith(status: 'reserved');
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pesanan Berhasil Dibuat!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo Anda sebesar ${PriceFormatter.formatIdr(listing.priceIdr)} telah ditahan dengan aman di sistem Rekber.',
                style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Temui penjual @${listing.sellerUsername ?? 'Penjual'} di titik COD yang disepakati. Setelah memeriksa fisik kartu, tekan "Sudah Kuterima" di menu Pesanan Saya.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop(true);
              },
              child: const Text('Tutup'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.onGold,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                );
              },
              child: const Text('Lihat Pesanan Saya'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pemesanan gagal: $e'),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCancelListing() async {
    final user = AppState.instance.currentUser.value;
    if (user == null || _listing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Batalkan Listing?'),
        content: const Text(
          'Kartu ini akan ditarik dari Marketplace dan tidak dapat dibeli oleh pengguna lain lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await MarketplaceRepository.cancelListing(
        listingId: _listing!.id,
        sellerId: user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing berhasil dibatalkan.'),
          backgroundColor: AppColors.snackBarSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan listing: $e'),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Listing')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (_errorMessage != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Listing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Listing tidak ditemukan.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, _hasChanged),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listing = _listing!;
    final card = listing.card;

    return ValueListenableBuilder(
      valueListenable: AppState.instance.currentUser,
      builder: (context, user, _) {
        return ValueListenableBuilder<AppCurrency>(
          valueListenable: AppState.instance.selectedCurrency,
          builder: (context, selectedCurrency, _) {
            final isOwnListing = user != null && user.id == listing.sellerId;
            final canBuy = listing.isActive &&
                !listing.isReserved &&
                !isOwnListing &&
                user != null &&
                user.balanceIdr >= listing.priceIdr;

            String displayPrice;
            if (selectedCurrency == AppCurrency.idr) {
              displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
            } else {
              final converted = CurrencyService.convert(
                listing.priceIdr,
                from: 'IDR',
                to: selectedCurrency.code,
              );
              displayPrice = converted != null
                  ? PriceFormatter.format(converted, selectedCurrency.code)
                  : PriceFormatter.formatIdr(listing.priceIdr);
            }

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(_hasChanged),
                ),
                title: Text(
                  card?.name ?? 'Detail Kartu',
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (isOwnListing && listing.isActive)
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.gold,
                      ),
                      tooltip: 'Edit Listing',
                      onPressed: _handleEditListing,
                    ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceHigh, width: 1),
                    ),
                  ),
                  child: isOwnListing
                      ? listing.isActive
                          ? Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      backgroundColor: AppColors.gold,
                                      foregroundColor: AppColors.onGold,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Edit Listing',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onPressed: _handleEditListing,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Batalkan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onPressed: _handleCancelListing,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              child: Text(
                                listing.isReserved
                                    ? 'Listing sedang Dipesan oleh Pembeli'
                                    : listing.isSold
                                        ? 'Kartu ini telah terjual'
                                        : 'Listing ini telah dibatalkan',
                                style: TextStyle(
                                  color: listing.isReserved
                                      ? AppColors.gold
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                      : Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga Listing',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      displayPrice,
                                      style: textTheme.titleLarge?.copyWith(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: canBuy
                                        ? AppColors.gold
                                        : AppColors.surfaceHigh,
                                    foregroundColor: canBuy
                                        ? AppColors.onGold
                                        : AppColors.onSurfaceVariant,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd,
                                      ),
                                    ),
                                  ),
                                  onPressed: (_isPurchasing ||
                                          !listing.isActive ||
                                          listing.isReserved)
                                      ? null
                                      : (user == null ||
                                              user.balanceIdr <
                                                  listing.priceIdr)
                                          ? () {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Saldo tidak cukup. Silakan top up di menu Marketplace.',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.snackBarError,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          : _handleBuy,
                                  child: _isPurchasing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.onGold,
                                          ),
                                        )
                                      : Text(
                                          listing.isSold
                                              ? 'Sudah Terjual'
                                              : listing.isReserved
                                                  ? 'Dipesan'
                                                  : (!listing.isActive)
                                                      ? 'Tidak Tersedia'
                                                      : (user != null &&
                                                              user.balanceIdr <
                                                                  listing
                                                                      .priceIdr)
                                                          ? 'Saldo Kurang'
                                                          : 'Pesan',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: AspectRatio(
                          aspectRatio: 63 / 88,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: card?.highResImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: card!.highResImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: AppColors.surfaceHigh,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: AppColors.surfaceHigh,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.surfaceHigh,
                                    child: const Icon(
                                      Icons.style_outlined,
                                      size: 48,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card?.name ?? 'Kartu Pokémon',
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${card?.setName ?? card?.setId ?? 'TCG Set'} · ${card?.rarity ?? 'Common'}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: listing.conditionBadgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            listing.conditionLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.query_stats,
                                color: AppColors.gold,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Informasi & Acuan Harga',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 4,
                            spacing: 8,
                            children: [
                              const Text(
                                'Harga Listing Penjual:',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                displayPrice,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (card?.priceIdr != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 4,
                              spacing: 8,
                              children: [
                                const Text(
                                  'Harga Pasar Acuan TCG:',
                                  style: TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  PriceFormatter.formatIdr(card!.priceIdr),
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.surfaceHigh,
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@${listing.sellerUsername ?? 'Penjual'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      isOwnListing
                                          ? 'Ini adalah listing milik Anda sendiri'
                                          : 'Penjual Terverifikasi HoloDex',
                                      style: TextStyle(
                                        color: isOwnListing
                                            ? AppColors.gold
                                            : AppColors.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (listing.lat != null && listing.lng != null) ...[
                            const Divider(height: 20),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MapScreen(
                                      initialCenter: LatLng(
                                        listing.lat!,
                                        listing.lng!,
                                      ),
                                      initialZoom: 15.5,
                                      focusedListing: listing,
                                      title:
                                          'Titik COD: ${listing.card?.name ?? 'Penjual'}',
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: AppColors.gold,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Koordinat COD: ${listing.lat!.toStringAsFixed(4)}, ${listing.lng!.toStringAsFixed(4)}',
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: AppColors.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Ketuk untuk lihat posisi di peta',
                                            style:
                                                textTheme.labelSmall?.copyWith(
                                              color: AppColors.cyan,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.gold,
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.map_outlined,
                                            size: 12,
                                            color: AppColors.gold,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Buka Peta',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.w700,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (listing.description != null &&
                        listing.description!.trim().isNotEmpty) ...[
                      Text(
                        'Catatan Penjual',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceHigh),
                        ),
                        child: Text(
                          listing.description!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
