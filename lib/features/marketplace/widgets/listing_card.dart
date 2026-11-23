import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = listing.card;

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
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppColors.surfaceHigh.withAlpha(128),
              width: 1,
            ),
          ),
          color: AppColors.surface,
          elevation: 2,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 63 / 88,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: card?.lowResImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: card!.lowResImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppColors.surfaceHigh,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: AppColors.surfaceHigh,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: AppColors.onSurfaceVariant,
                                          size: 32,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.surfaceHigh,
                                      child: const Icon(
                                        Icons.style_outlined,
                                        color: AppColors.onSurfaceVariant,
                                        size: 32,
                                      ),
                                    ),
                            ),
                            // Badge Kondisi Kartu
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: listing.conditionBadgeColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  listing.condition
                                      .toUpperCase()
                                      .replaceAll('_', ' '),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            // Badge Dipesan (Reserved)
                            if (listing.isReserved)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_clock,
                                        color: Colors.black,
                                        size: 10,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'DIPESAN',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 8),
                  Text(
                    card?.name ?? 'Kartu Pokémon',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${card?.setName ?? card?.setId ?? 'TCG'} ${card?.localId != null ? '#${card!.localId}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayPrice,
                      maxLines: 1,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '@${listing.sellerUsername ?? 'Penjual'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
