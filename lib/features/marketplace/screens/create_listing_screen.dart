import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/database/initial_data_seeder.dart';
import '../../../core/models/card_model.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/repositories/card_repository.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../profile/widgets/whatsapp_dialog.dart';
import '../widgets/location_picker_dialog.dart';

class CreateListingScreen extends StatefulWidget {
  final CardModel? preselectedCard;
  final ListingModel? existingListing;

  const CreateListingScreen({
    super.key,
    this.preselectedCard,
    this.existingListing,
  });

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  CardModel? _selectedCard;
  String _condition = 'near_mint';
  String _selectedCity = 'Jakarta Pusat';
  String? _locationName;
  double _lat = -6.2088;
  double _lng = 106.8456;
  bool _isSubmitting = false;
  bool _isLocatingGps = false;

  bool get _isEditMode => widget.existingListing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingListing;
    if (existing != null) {
      _selectedCard = existing.card;
      _priceController.text = existing.priceIdr.round().toString();
      _condition = existing.condition;
      _descController.text = existing.description ?? '';
      _lat = existing.lat ?? -6.2088;
      _lng = existing.lng ?? 106.8456;
      if (_selectedCard == null) {
        _loadCardForExisting(existing.cardId);
      }
    } else {
      _selectedCard = widget.preselectedCard;
      if (_selectedCard?.priceIdr != null) {
        _priceController.text = _selectedCard!.priceIdr!.round().toString();
      }
    }
  }

  Future<void> _loadCardForExisting(String cardId) async {
    final card = await CardRepository.getCardById(
      cardId,
      fetchFromApiIfMissing: false,
    );
    if (mounted && card != null) {
      setState(() => _selectedCard = card);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    final result = await LocationPickerDialog.show(
      context,
      initialLat: _lat,
      initialLng: _lng,
      initialCity: _selectedCity,
      initialLocationName: _locationName,
    );

    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _selectedCity = result.city;
        _locationName = result.locationName;
      });
    }
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titik GPS berhasil dikunci sebagai lokasi COD!'),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        final explanation = await LocationService.getStatusExplanation();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(explanation),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  void _openCardPicker() {
    if (_isEditMode) return; // Kartu tidak diganti pada mode Edit Listing
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CardPickerSheet(
        onCardSelected: (card) {
          setState(() {
            _selectedCard = card;
            if (_priceController.text.isEmpty && card.priceIdr != null) {
              _priceController.text = card.priceIdr!.round().toString();
            }
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _submitListing() async {
    final user = AppState.instance.currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu.'),
          backgroundColor: AppColors.snackBarError,
        ),
      );
      return;
    }

    if (!_isEditMode && _selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih kartu Pokémon yang ingin dijual terlebih dahulu.',
          ),
          backgroundColor: AppColors.snackBarError,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(
      _priceController.text.replaceAll('.', '').trim(),
    );
    if (price == null || price < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga minimal listing adalah Rp 1.000.'),
          backgroundColor: AppColors.snackBarError,
        ),
      );
      return;
    }

    // Pengecekan Just-in-Time: Penjual wajib memiliki nomor WhatsApp
    final latestUser = AppState.instance.currentUser.value ?? user;
    if (latestUser.whatsappNumber == null ||
        latestUser.whatsappNumber!.trim().isEmpty) {
      final savedPhone = await WhatsAppDialog.show(
        context,
        customTitle: 'Nomor WhatsApp Penjual',
        customExplanation:
            'Nomor WhatsApp diperlukan agar pembeli dapat menghubungi kamu setelah memesan kartu untuk koordinasi COD.',
      );

      if (savedPhone == null || savedPhone.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dibatalkan: Nomor WhatsApp wajib diisi untuk koordinasi COD.',
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
    setState(() => _isSubmitting = true);

    final formattedDesc = (_locationName != null && _locationName!.isNotEmpty)
        ? (_descController.text.trim().isNotEmpty
            ? 'Patokan COD: $_locationName\n\n${_descController.text.trim()}'
            : 'Patokan COD: $_locationName')
        : (_descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null);

    try {
      if (_isEditMode) {
        await MarketplaceRepository.updateListing(
          listingId: widget.existingListing!.id,
          currentUserId: user.id,
          priceIdr: price,
          condition: _condition,
          description: formattedDesc,
          lat: _lat,
          lng: _lng,
        );
      } else {
        await MarketplaceRepository.createListing(
          cardId: _selectedCard!.id,
          sellerId: user.id,
          priceIdr: price,
          condition: _condition,
          description: formattedDesc,
          lat: _lat,
          lng: _lng,
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Perubahan listing berhasil disimpan!'
                : 'Listing kartu berhasil dipasang di Marketplace!',
          ),
          backgroundColor: AppColors.snackBarSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorText = e is MarketplaceFailure ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Listing Kartu' : 'Pasang Listing Kartu',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pemilih Kartu
            Text(
              'Kartu Pokémon Fisik',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isEditMode ? null : _openCardPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedCard != null
                        ? AppColors.gold.withAlpha(128)
                        : AppColors.surfaceHigh,
                  ),
                ),
                child: _selectedCard == null
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pilih Kartu dari Koleksi / Katalog',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 50,
                              height: 70,
                              child: _selectedCard!.lowResImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _selectedCard!.lowResImageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: AppColors.surfaceHigh),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCard!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedCard!.setName ?? _selectedCard!.setId ?? 'TCG'} · ${_selectedCard!.rarity ?? 'Kartu'}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                if (_selectedCard!.priceIdr != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Acuan Pasar: ${PriceFormatter.formatIdr(_selectedCard!.priceIdr)}',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!_isEditMode)
                            const Icon(
                              Icons.swap_horiz,
                              color: AppColors.onSurfaceVariant,
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Input Harga
            Text(
              'Harga Jual (IDR)',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: 'Contoh: 150000',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Harga jual wajib diisi';
                }
                final numVal = double.tryParse(val.trim());
                if (numVal == null || numVal < 1000) {
                  return 'Harga minimal Rp 1.000';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Pilihan Kondisi Kartu
            Text(
              'Kondisi Fisik Kartu',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildConditionChoice('mint', 'Mint (Sempurna)'),
                _buildConditionChoice('near_mint', 'Near Mint (Mulus)'),
                _buildConditionChoice('excellent', 'Excellent (Bagus)'),
                _buildConditionChoice('good', 'Good (Terawat)'),
                _buildConditionChoice('poor', 'Poor (Ada Minus)'),
              ],
            ),
            const SizedBox(height: 20),

            // Lokasi Titik COD Penjual
            Text(
              'Titik Lokasi COD Penjual',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCity,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Koordinat: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_locationName != null && _locationName!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Patokan: $_locationName',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            foregroundColor: AppColors.gold,
                            side: const BorderSide(
                              color: AppColors.gold,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: _openLocationPicker,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text(
                            'Pilih di Peta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            foregroundColor: AppColors.cyan,
                            side: BorderSide(
                              color: AppColors.cyan.withValues(alpha: 0.7),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed:
                              _isLocatingGps ? null : _useCurrentGpsLocation,
                          icon: _isLocatingGps
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.cyan,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 16),
                          label: const Text(
                            'Pakai GPS',
                            style: TextStyle(
                              fontSize: 12,
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
            const SizedBox(height: 20),

            // Deskripsi / Catatan Penjual
            Text(
              'Deskripsi / Catatan Kondisi',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Misal: Sudah pakai toploader & double sleeve, siap COD.',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Submit
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.onGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitListing,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onGold,
                        ),
                      )
                    : Text(
                        _isEditMode
                            ? 'Simpan Perubahan Listing'
                            : 'Pasang Listing ke Marketplace',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionChoice(String key, String label) {
    final isSelected = _condition == key;
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
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
        ),
      ),
      onSelected: (val) {
        if (val) setState(() => _condition = key);
      },
    );
  }
}

/// Modal Bottom Sheet untuk memilih kartu dari Koleksi Saya atau Katalog Dex (Hive)
class _CardPickerSheet extends StatefulWidget {
  final ValueChanged<CardModel> onCardSelected;

  const _CardPickerSheet({required this.onCardSelected});

  @override
  State<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends State<_CardPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _catalogSearchController =
      TextEditingController();
  List<CardModel> _collectionCards = [];
  List<CardModel> _catalogSearchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCollectionAndCatalog();
  }

  Future<void> _loadCollectionAndCatalog() async {
    final userId =
        AppState.instance.currentUser.value?.id ?? InitialDataSeeder.demoUserId;
    final items = await CollectionRepository.getCollectionCards(userId);
    if (!mounted) return;
    setState(() {
      _collectionCards = items.map((e) => e.card).whereType<CardModel>().toList();
      _catalogSearchResults = CardRepository.searchCards();
    });
  }

  void _searchCatalog(String query) {
    setState(() {
      _catalogSearchResults = CardRepository.searchCards(query: query);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _catalogSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih Kartu yang Dijual',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Koleksi Saya (Jual Kembali)'),
              Tab(text: 'Katalog Dex (Kartu Baru)'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _collectionCards.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Koleksi Anda masih kosong.\nBeli kartu di Marketplace atau pilih dari tab Katalog Dex.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _collectionCards.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: AppColors.surfaceHigh,
                        ),
                        itemBuilder: (ctx, index) =>
                            _buildCardTile(_collectionCards[index]),
                      ),
                Column(
                  children: [
                    TextField(
                      controller: _catalogSearchController,
                      onChanged: _searchCatalog,
                      decoration: InputDecoration(
                        hintText: 'Cari nama kartu di katalog...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _catalogSearchResults.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada kartu ditemukan.',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _catalogSearchResults.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                height: 1,
                                color: AppColors.surfaceHigh,
                              ),
                              itemBuilder: (ctx, index) =>
                                  _buildCardTile(_catalogSearchResults[index]),
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
  }

  Widget _buildCardTile(CardModel card) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 40,
          height: 56,
          child: card.lowResImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: card.lowResImageUrl!,
                  fit: BoxFit.cover,
                )
              : Container(color: AppColors.surfaceHigh),
        ),
      ),
      title: Text(
        card.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        '${card.setName ?? card.setId ?? ''} · Acuan: ${PriceFormatter.formatIdr(card.priceIdr)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => widget.onCardSelected(card),
    );
  }
}
