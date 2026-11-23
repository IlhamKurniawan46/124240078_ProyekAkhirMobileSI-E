import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/utils/price_formatter.dart';
import 'listing_detail_screen.dart';

/// Pasangan Listing dan jaraknya dari titik lokasi pengguna (km)
class ListingWithDistance {
  final ListingModel listing;
  final double distanceKm;

  const ListingWithDistance({
    required this.listing,
    required this.distanceKm,
  });
}

class MapScreen extends StatefulWidget {
  final LatLng? initialCenter;
  final double? initialZoom;
  final ListingModel? focusedListing;
  final String? title;

  const MapScreen({
    super.key,
    this.initialCenter,
    this.initialZoom,
    this.focusedListing,
    this.title,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultMonasLocation = LatLng(-6.1754, 106.8272);

  late final MapController _mapController;
  List<ListingModel> _allListings = [];
  LatLng _userLocation = _defaultMonasLocation;
  double? _selectedRadiusKm;
  ListingModel? _selectedListing;
  String? _locationErrorMessage;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedListing = widget.focusedListing;
    _loadListingsAndLocation();
  }

  Future<void> _loadListingsAndLocation() async {
    final listings = await MarketplaceRepository.fetchActiveListings();
    if (!mounted) return;
    setState(() {
      _allListings = listings
          .where((l) => l.lat != null && l.lng != null)
          .toList();
    });
    await _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locationErrorMessage = null;
        });
      } else {
        final msg = await LocationService.getStatusExplanation();
        if (!mounted) return;
        setState(() {
          _userLocation = _defaultMonasLocation;
          _locationErrorMessage = msg;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLocation = _defaultMonasLocation;
      });
    }
  }

  List<ListingWithDistance> get _filteredListingsWithDistance {
    final result = <ListingWithDistance>[];
    for (final l in _allListings) {
      if (l.lat == null || l.lng == null) continue;
      final dist = LocationService.calculateDistanceKm(
        startLatitude: _userLocation.latitude,
        startLongitude: _userLocation.longitude,
        endLatitude: l.lat!,
        endLongitude: l.lng!,
      );
      if (_selectedRadiusKm == null || dist <= _selectedRadiusKm!) {
        result.add(ListingWithDistance(listing: l, distanceKm: dist));
      }
    }
    result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final listingsWithDistance = _filteredListingsWithDistance;
    final selectedListing = _selectedListing;
    final userLoc = _userLocation;
    final centerPoint = widget.initialCenter ?? userLoc;
    final effectiveZoom =
        widget.initialZoom ?? (widget.initialCenter != null ? 15.0 : 12.0);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Peta Penjual Terdekat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui Lokasi GPS',
            onPressed: _loadListingsAndLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: effectiveZoom,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                setState(() => _selectedListing = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.ac.holodex',
              ),
              if (_selectedRadiusKm != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: userLoc,
                      color: AppColors.gold.withAlpha(38),
                      borderColor: AppColors.gold,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: _selectedRadiusKm! * 1000,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // 1. Marker Lokasi Pengguna
                  Marker(
                    point: userLoc,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withAlpha(64),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Marker Listing Penjual
                  ...listingsWithDistance.map((item) {
                    final listing = item.listing;
                    final point = LatLng(listing.lat!, listing.lng!);
                    final isSelected = selectedListing?.id == listing.id;
                    final isCodPoint = widget.initialCenter != null &&
                        (listing.lat! - widget.initialCenter!.latitude).abs() <
                            0.0001 &&
                        (listing.lng! - widget.initialCenter!.longitude).abs() <
                            0.0001;

                    return Marker(
                      point: point,
                      width: (isSelected || isCodPoint) ? 52 : 38,
                      height: (isSelected || isCodPoint) ? 52 : 38,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedListing = listing);
                          _mapController.move(point, 15.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isCodPoint
                                ? AppColors.gold
                                : (isSelected
                                    ? AppColors.gold
                                    : Colors.black87),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCodPoint
                                  ? Colors.redAccent
                                  : (isSelected
                                      ? Colors.black
                                      : AppColors.gold),
                              width: isCodPoint ? 3 : 2,
                            ),
                          ),
                          child: Icon(
                            isCodPoint ? Icons.handshake : Icons.storefront,
                            size: (isSelected || isCodPoint) ? 26 : 20,
                            color: isCodPoint
                                ? Colors.black
                                : (isSelected ? Colors.black : AppColors.gold),
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Marker Khusus Focused Listing jika status reserved
                  if (widget.focusedListing != null &&
                      widget.focusedListing!.lat != null &&
                      widget.focusedListing!.lng != null &&
                      !listingsWithDistance.any(
                        (item) => item.listing.id == widget.focusedListing!.id,
                      ))
                    Marker(
                      point: LatLng(
                        widget.focusedListing!.lat!,
                        widget.focusedListing!.lng!,
                      ),
                      width: 56,
                      height: 56,
                      child: GestureDetector(
                        onTap: () {
                          setState(
                            () => _selectedListing = widget.focusedListing,
                          );
                          _mapController.move(
                            LatLng(
                              widget.focusedListing!.lat!,
                              widget.focusedListing!.lng!,
                            ),
                            15.5,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.redAccent,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.handshake,
                            size: 28,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Baris Chip Filter Radius di Bagian Atas
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRadiusChip(null, 'Semua Jarak'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(5, '5 km'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(10, '10 km'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(25, '25 km'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(50, '50 km'),
                  ],
                ),
              ),
            ),
          ),

          // FAB "Lokasi Saya"
          Positioned(
            right: 16,
            bottom: selectedListing != null ? 180 : 24,
            child: FloatingActionButton.small(
              heroTag: 'map_my_location_btn',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.gold,
              elevation: 4,
              onPressed: () {
                _mapController.move(userLoc, 14.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          if (_locationErrorMessage != null)
            Positioned(
              bottom: selectedListing != null ? 180 : 24,
              left: 16,
              right: 76,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(235),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.gold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationErrorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (selectedListing != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildListingBottomCard(
                context: context,
                listing: selectedListing,
                userLocation: userLoc,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(double? radiusKm, String label) {
    final isSelected = _selectedRadiusKm == radiusKm;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.gold,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: isSelected ? AppColors.gold : Colors.transparent,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedRadiusKm = radiusKm);
        }
      },
    );
  }

  Widget _buildListingBottomCard({
    required BuildContext context,
    required ListingModel listing,
    required LatLng userLocation,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final card = listing.card;

    double? distanceKm;
    if (listing.lat != null && listing.lng != null) {
      distanceKm = LocationService.calculateDistanceKm(
        startLatitude: userLocation.latitude,
        startLongitude: userLocation.longitude,
        endLatitude: listing.lat!,
        endLongitude: listing.lng!,
      );
    }
    final distanceText =
        distanceKm != null ? LocationService.formatDistance(distanceKm) : null;

    return ValueListenableBuilder<AppCurrency>(
      valueListenable: AppState.instance.selectedCurrency,
      builder: (context, selectedCurrency, _) {
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

        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _selectedListing = null),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${listing.sellerUsername ?? 'Penjual'} · ${listing.conditionLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 4,
                            spacing: 8,
                            children: [
                              Text(
                                displayPrice,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (distanceText != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.near_me,
                                        size: 10,
                                        color: AppColors.gold,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        distanceText,
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text(
                      'Lihat Detail Kartu',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(
                            listingId: listing.id,
                            initialListing: listing,
                          ),
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
}
