import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/models/collection_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../auth/screens/login_screen.dart';
import '../../marketplace/screens/my_orders_screen.dart';
import '../../marketplace/screens/transaction_history_screen.dart';
import '../widgets/whatsapp_dialog.dart';
import 'collection_screen.dart';
import 'watchlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isUploadingPhoto = false;
  bool _isLoadingData = true;
  double _heldEscrowIdr = 0.0;
  List<CollectionItemModel> _collectionItems = [];
  int _watchlistCount = 0;
  List<OrderModel> _myOrders = [];

  @override
  void initState() {
    super.initState();
    AppState.instance.currentUser.addListener(_onUserChanged);
    _loadProfileData();
  }

  @override
  void dispose() {
    AppState.instance.currentUser.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) {
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
    final user = AppState.instance.currentUser.value;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
      return;
    }

    try {
      await CurrencyService.initRates();
      final results = await Future.wait([
        OrderRepository.getHeldEscrowBalance(user.id),
        CollectionRepository.getCollectionCards(user.id),
        CollectionRepository.getWatchlist(user.id),
        OrderRepository.getMyOrders(user.id),
      ]);

      if (!mounted) return;
      setState(() {
        _heldEscrowIdr = results[0] as double;
        _collectionItems = results[1] as List<CollectionItemModel>;
        _watchlistCount = (results[2] as List).length;
        _myOrders = results[3] as List<OrderModel>;
        _isLoadingData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAndSaveImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;

      final currentUser = AppState.instance.currentUser.value;
      if (currentUser == null) return;

      setState(() => _isUploadingPhoto = true);

      await AuthService.updateUserPhoto(currentUser.id, image.path);

      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui!'),
          backgroundColor: AppColors.snackBarSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih gambar: $e'),
          backgroundColor: AppColors.snackBarError,
        ),
      );
    }
  }

  Future<void> _removePhoto() async {
    final currentUser = AppState.instance.currentUser.value;
    if (currentUser == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await AuthService.updateUserPhoto(currentUser.id, null);
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoPickerBottomSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.gold),
                ),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSaveImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.cyan,
                  ),
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSaveImage(ImageSource.gallery);
                },
              ),
              if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  title: const Text(
                    'Hapus Foto Profil',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(UserModel user) {
    final photoPath = user.photoUrl;
    ImageProvider? imageProvider;

    if (photoPath != null && photoPath.isNotEmpty) {
      if (photoPath.startsWith('http')) {
        imageProvider = NetworkImage(photoPath);
      } else {
        final file = File(photoPath);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    return GestureDetector(
      onTap: () => _showPhotoPickerBottomSheet(context, user),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.surface,
              backgroundImage: imageProvider,
              child: _isUploadingPhoto
                  ? const CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2.5,
                    )
                  : (imageProvider == null
                        ? Text(
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : 'T',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          )
                        : null),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceLowest, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog(BuildContext context, UserModel user) {
    final customAmountController = TextEditingController();
    final presetAmounts = [100000.0, 250000.0, 500000.0, 1000000.0];
    final parentMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        bool isProcessing = false;

        Future<void> executeTopUp(double amount) async {
          if (amount <= 0) return;
          isProcessing = true;
          (ctx as Element).markNeedsBuild();
          final sheetNavigator = Navigator.of(ctx);
          final sheetMessenger = ScaffoldMessenger.of(ctx);

          try {
            final newBalance = await AuthService.topUpBalance(
              userId: user.id,
              amountIdr: amount,
            );

            if (!ctx.mounted) return;
            sheetNavigator.pop();

            parentMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Top up ${PriceFormatter.formatIdr(amount)} berhasil! Saldo kini ${PriceFormatter.formatIdr(newBalance)}',
                ),
                backgroundColor: AppColors.snackBarSuccess,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (e) {
            isProcessing = false;
            if (ctx.mounted) {
              (ctx).markNeedsBuild();
              sheetMessenger.showSnackBar(
                SnackBar(
                  content: Text('Gagal Top Up: $e'),
                  backgroundColor: AppColors.snackBarError,
                ),
              );
            }
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Top Up Saldo Virtual',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih nominal instan atau ketik jumlah saldo simulasi untuk berbelanja di Pasar HoloDex:',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: presetAmounts.map((amt) {
                  return ActionChip(
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                    label: Text(
                      '+ ${PriceFormatter.formatIdr(amt)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: isProcessing ? null : () => executeTopUp(amt),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: customAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Atau masukkan nominal lain (Rp)',
                  hintText: 'Contoh: 750000',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () {
                        final raw = customAmountController.text.replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        );
                        final parsed = double.tryParse(raw) ?? 0;
                        if (parsed < 10000) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Minimal top up adalah Rp 10.000'),
                              backgroundColor: AppColors.snackBarError,
                            ),
                          );
                          return;
                        }
                        executeTopUp(parsed);
                      },
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.add_card_rounded),
                label: Text(
                  isProcessing ? 'Memproses...' : 'Tambah Saldo Sekarang',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLow,
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Sesi aktif akan dihapus. Anda dapat masuk kembali kapan saja menggunakan akun Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.snackBarError,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AppState.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil Kolektor')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Anda belum masuk ke akun.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text('Masuk Sekarang'),
                  ),
                ],
              ),
            ),
          );
        }

        return ValueListenableBuilder<AppCurrency>(
          valueListenable: AppState.instance.selectedCurrency,
          builder: (context, selectedCurrency, _) {
            double totalDisplayValue = 0.0;
            for (final item in _collectionItems) {
              if (item.card == null) continue;
              final val = CardPriceCalculator.getConvertedPrice(
                item.card!,
                selectedCurrency,
              );
              if (val != null) {
                totalDisplayValue += val;
              }
            }

            final activeOrderCount = _myOrders
                .where((o) => o.status == OrderStatus.reserved)
                .length;

            final rawWa = user.whatsappNumber;
            final hasWa = rawWa != null && rawWa.trim().isNotEmpty;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Profil Kolektor'),
                actions: [
                  IconButton(
                    tooltip: 'Muat Ulang Data Profil',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadProfileData,
                  ),
                ],
              ),
              body: RefreshIndicator(
                color: AppColors.gold,
                onRefresh: _loadProfileData,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          _buildAvatarWidget(user),
                          const SizedBox(height: 12),
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user.email != null && user.email!.isNotEmpty)
                            Text(
                              user.email!,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () =>
                                _showPhotoPickerBottomSheet(context, user),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text(
                              'Ganti Foto Profil',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kartu Saldo Virtual + Escrow Rekber + Top Up
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Saldo Tersedia (IDR)',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      PriceFormatter.formatIdr(user.balanceIdr),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showTopUpDialog(context, user),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Top Up'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(96, 40),
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_heldEscrowIdr > 0) ...[
                            const Divider(height: 20, color: Colors.white12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ditahan di Rekber (Escrow): ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  PriceFormatter.formatIdr(_heldEscrowIdr),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kartu Total Nilai Portofolio Binder
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectionScreen(),
                          ),
                        );
                        if (mounted) _loadProfileData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.cyan.withValues(alpha: 0.22),
                              const Color(0xFF0F172A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.cyan.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_motion_rounded,
                                color: AppColors.cyan,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Nilai Portofolio (${selectedCurrency.code})',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isLoadingData
                                        ? 'Menghitung...'
                                        : '${PriceFormatter.format(totalDisplayValue, selectedCurrency.code)} • ${_collectionItems.length} Kartu',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.cyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Pengaturan Kontak COD (WhatsApp)
                    const Text(
                      'Pengaturan Kontak COD',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF25D366)
                              .withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF25D366),
                          ),
                        ),
                        title: const Text(
                          'Nomor WhatsApp COD',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          hasWa
                              ? '${WhatsAppHelper.maskPhoneNumber(rawWa)} (Hanya tampil ke lawan transaksi)'
                              : 'Belum diatur • Wajib diisi sebelum jual/beli kartu',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasWa ? AppColors.cyan : Colors.amber,
                          ),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(64, 36),
                            side: BorderSide(
                              color: hasWa ? Colors.white24 : AppColors.gold,
                            ),
                            foregroundColor: hasWa
                                ? Colors.white
                                : AppColors.gold,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () async {
                            final savedPhone = await WhatsAppDialog.show(
                              context,
                              initialPhone: rawWa,
                            );
                            if (savedPhone != null && mounted) {
                              _loadProfileData();
                            }
                          },
                          child: Text(hasWa ? 'Ubah' : 'Atur'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Menu Kolektor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _ProfileMenuTile(
                      icon: Icons.collections_bookmark_rounded,
                      title: 'Koleksi Saya (Binder Fisik)',
                      subtitle:
                          'Kartu hasil pembelian COD (${_collectionItems.length} kartu)',
                      badgeText: '${_collectionItems.length}',
                      badgeColor: AppColors.cyan,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CollectionScreen(),
                          ),
                        );
                        if (mounted) _loadProfileData();
                      },
                    ),
                    _ProfileMenuTile(
                      icon: Icons.handshake_rounded,
                      title: 'Pesanan Saya (Rekber COD)',
                      subtitle: 'Pantau pesanan aktif, konfirmasi COD & hubungi WhatsApp',
                      badgeText: activeOrderCount > 0
                          ? '$activeOrderCount Aktif'
                          : null,
                      badgeColor: AppColors.gold,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyOrdersScreen(),
                          ),
                        );
                        if (mounted) _loadProfileData();
                      },
                    ),
                    _ProfileMenuTile(
                      icon: Icons.notifications_active_rounded,
                      title: 'Watchlist & Target Harga',
                      subtitle:
                          'Kartu incaran dan pengingat harga turun ($_watchlistCount kartu)',
                      badgeText: _watchlistCount > 0
                          ? '$_watchlistCount'
                          : null,
                      badgeColor: AppColors.pink,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WatchlistScreen(),
                          ),
                        );
                        if (mounted) _loadProfileData();
                      },
                    ),
                    _ProfileMenuTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Riwayat Transaksi',
                      subtitle: 'Catatan mutasi pembelian dan penjualan kartu',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransactionHistoryScreen(),
                          ),
                        );
                        if (mounted) _loadProfileData();
                      },
                    ),

                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _confirmAndLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Keluar dari Akun',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 24),
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

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.gold),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.gold).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: badgeColor ?? AppColors.gold,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? AppColors.gold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
