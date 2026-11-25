import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../database/hive_database.dart';
import '../models/card_model.dart';
import '../services/currency_service.dart';

/// Pilihan pengurutan kartu di Katalog Dex.
enum SortOrder {
  expensiveFirst('Termahal', 'Harga tertinggi ke terendah'),
  cheapestFirst('Termurah', 'Harga terendah ke tertinggi'),
  nameAsc('Nama (A-Z)', 'Urutkan alfabetis nama kartu');

  final String label;
  final String description;
  const SortOrder(this.label, this.description);
}

/// State filter pencarian katalog (menggantikan SearchState Riverpod).
class CatalogFilterState {
  final String query;
  final String? selectedSetId;
  final String? selectedRarity;
  final double? minPrice;
  final double? maxPrice;
  final List<Map<String, String>> availableSets;
  final List<String> availableRarities;

  const CatalogFilterState({
    this.query = '',
    this.selectedSetId,
    this.selectedRarity,
    this.minPrice,
    this.maxPrice,
    this.availableSets = const [],
    this.availableRarities = const [],
  });

  bool get hasActiveFilters =>
      selectedSetId != null ||
      selectedRarity != null ||
      minPrice != null ||
      maxPrice != null;

  int get activeFilterCount {
    int count = 0;
    if (selectedSetId != null) count++;
    if (selectedRarity != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    return count;
  }
}

/// Menghubungkan `holodex_cards` Hive Box dengan **TCGdex REST API** (`https://api.tcgdex.net/v2/en/`).
class CardRepository {
  CardRepository._();

  /// Daftar 4 set resmi yang didukung sinkronisasi online TCGdex API
  static const List<Map<String, String>> targetSets = [
    {'id': 'swsh7', 'name': 'Evolving Skies'},
    {'id': 'swsh3', 'name': 'Darkness Ablaze'},
    {'id': 'sv01', 'name': 'Scarlet & Violet'},
    {'id': 'sv05', 'name': 'Temporal Forces'},
  ];

  /// Mengambil seluruh kartu dari `holodex_cards` Hive Box dengan pengurutan.
  static List<CardModel> getAllCards({
    SortOrder sortOrder = SortOrder.expensiveFirst,
    bool onlyPriced = false,
  }) {
    final cards = <CardModel>[];
    for (final raw in HiveDatabase.cardsBox.values) {
      if (raw is! Map) continue;
      final card = CardModel.fromMap(HiveDatabase.readMap(raw));
      if (onlyPriced && !card.hasPrice) continue;
      cards.add(card);
    }

    _sortCards(cards, sortOrder);
    return cards;
  }

  /// Ambil satu kartu berdasarkan `cardId` dari `holodex_cards` Hive Box.
  /// Jika belum ada di Hive dan `fetchFromApiIfMissing == true`, otomatis HTTP GET ke TCGdex API.
  static Future<CardModel?> getCardById(
    String cardId, {
    bool fetchFromApiIfMissing = true,
  }) async {
    final raw = HiveDatabase.cardsBox.get(cardId);
    if (raw != null && raw is Map) {
      return CardModel.fromMap(HiveDatabase.readMap(raw));
    }

    if (fetchFromApiIfMissing) {
      return fetchCardDetailFromApi(cardId);
    }
    return null;
  }

  /// Pencarian dan penyaringan multi-kriteria langsung pada `holodex_cards` Hive Box.
  static List<CardModel> searchCards({
    String query = '',
    String? setId,
    String? rarity,
    double? minPriceIdr,
    double? maxPriceIdr,
    SortOrder sortOrder = SortOrder.expensiveFirst,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final cleanSet = setId?.trim().toLowerCase();
    final cleanRarity = rarity?.trim().toLowerCase();
    final usdToIdr = CurrencyService.usdToIdrRate > 0
        ? CurrencyService.usdToIdrRate
        : 16500.0;

    final results = <CardModel>[];

    for (final raw in HiveDatabase.cardsBox.values) {
      if (raw is! Map) continue;
      final card = CardModel.fromMap(HiveDatabase.readMap(raw));

      // 1. Filter kata kunci (nama kartu atau nomor localId)
      if (cleanQuery.isNotEmpty) {
        final nameMatch = card.name.toLowerCase().contains(cleanQuery);
        final localIdMatch =
            (card.localId ?? '').toLowerCase().contains(cleanQuery);
        final setMatch =
            (card.setName ?? '').toLowerCase().contains(cleanQuery);
        if (!nameMatch && !localIdMatch && !setMatch) continue;
      }

      // 2. Filter Set ID
      if (cleanSet != null && cleanSet.isNotEmpty) {
        if ((card.setId ?? '').toLowerCase() != cleanSet) continue;
      }

      // 3. Filter Rarity
      if (cleanRarity != null && cleanRarity.isNotEmpty) {
        if ((card.rarity ?? '').toLowerCase() != cleanRarity) continue;
      }

      // 4. Filter Rentang Harga IDR
      final effectiveIdr = card.priceRefUsd != null
          ? card.priceRefUsd! * usdToIdr
          : (card.priceIdr ?? 0.0);

      if (minPriceIdr != null && effectiveIdr < minPriceIdr) continue;
      if (maxPriceIdr != null && effectiveIdr > maxPriceIdr) continue;

      results.add(card);
    }

    _sortCards(results, sortOrder);
    return results;
  }

  /// Ambil daftar set unik yang ada di `holodex_cards` Hive Box.
  static List<Map<String, String>> getAvailableSets() {
    final setMap = <String, String>{};
    for (final raw in HiveDatabase.cardsBox.values) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      final id = map['set_id'] as String?;
      if (id != null && id.trim().isNotEmpty) {
        final name = (map['set_name'] as String?) ?? id.toUpperCase();
        setMap[id] = name;
      }
    }

    final list = setMap.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList();
    list.sort((a, b) => a['name']!.compareTo(b['name']!));
    return list;
  }

  /// Ambil daftar rarity unik yang ada di `holodex_cards` Hive Box.
  static List<String> getAvailableRarities() {
    final rarities = <String>{};
    for (final raw in HiveDatabase.cardsBox.values) {
      if (raw is! Map) continue;
      final map = HiveDatabase.readMap(raw);
      final rarity = map['rarity'] as String?;
      if (rarity != null && rarity.trim().isNotEmpty) {
        rarities.add(rarity);
      }
    }

    final list = rarities.toList();
    list.sort();
    return list;
  }

  /// Mengambil detail 1 kartu beserta harga pasar (TCGplayer & Cardmarket)
  /// langsung dari **TCGdex REST API** (`GET /v2/en/cards/{cardId}`) dan menyimpannya ke Hive.
  static Future<CardModel?> fetchCardDetailFromApi(String cardId) async {
    final url = Uri.parse('${AppConstants.tcgdexBaseUrl}/cards/$cardId');
    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final card = parseTcgdexCardJson(data);
      if (card != null) {
        await HiveDatabase.cardsBox.put(card.id, card.toMap());
      }
      return card;
    } catch (e) {
      debugPrint('[HoloDex Warning] Gagal fetch detail kartu $cardId dari TCGdex API: $e');
      return null;
    }
  }

  /// Mengekstrak objek [CardModel] beserta harga `tcgplayer` & `cardmarket`
  /// dari JSON resmi TCGdex REST API (`/v2/en/cards/{id}`).
  static CardModel? parseTcgdexCardJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    final imageUrl = json['image']?.toString();
    if (id == null || name == null || imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    final setMap = json['set'] is Map
        ? Map<String, dynamic>.from(json['set'] as Map)
        : <String, dynamic>{};
    final typesList = json['types'] is List ? (json['types'] as List) : const [];
    final cardType = typesList.isNotEmpty
        ? typesList.first.toString()
        : (json['category']?.toString() ?? 'Pokémon');

    // Ekstraksi harga dari field `pricing` TCGdex
    double? priceUsd;
    double? priceEur;
    String? priceSource;

    if (json['pricing'] is Map) {
      final pricing = Map<String, dynamic>.from(json['pricing'] as Map);

      // 1. TCGplayer (USD) — cari marketPrice tertinggi dari varian
      if (pricing['tcgplayer'] is Map) {
        final tcg = Map<String, dynamic>.from(pricing['tcgplayer'] as Map);
        const variants = [
          'holofoil',
          'normal',
          'reverse-holofoil',
          '1st-edition-holofoil',
          'unlimited-holofoil',
        ];
        for (final v in variants) {
          if (tcg[v] is Map) {
            final vMap = Map<String, dynamic>.from(tcg[v] as Map);
            final mp = (vMap['marketPrice'] ?? vMap['midPrice']) as num?;
            if (mp != null && mp.toDouble() > 0) {
              if (priceUsd == null || mp.toDouble() > priceUsd) {
                priceUsd = mp.toDouble();
              }
            }
          }
        }
      }

      // 2. Cardmarket (EUR) — ambil trend atau avg30
      if (pricing['cardmarket'] is Map) {
        final cm = Map<String, dynamic>.from(pricing['cardmarket'] as Map);
        final eurVal = (cm['trend'] ?? cm['avg30'] ?? cm['avg7'] ?? cm['avg1']) as num?;
        if (eurVal != null && eurVal.toDouble() > 0) {
          priceEur = eurVal.toDouble();
        }
      }
    }

    final eurToUsd = CurrencyService.eurToUsdRate;
    final usdToIdr = CurrencyService.usdToIdrRate;

    double? priceRefUsd;
    if (priceUsd != null && priceUsd > 0) {
      priceRefUsd = priceUsd;
      priceSource = 'tcgplayer';
    } else if (priceEur != null && priceEur > 0) {
      priceRefUsd = double.parse((priceEur * eurToUsd).toStringAsFixed(2));
      priceSource = 'cardmarket';
    }

    final hasPrice = priceRefUsd != null && priceRefUsd > 0;
    final priceIdr = hasPrice ? (priceRefUsd * usdToIdr).roundToDouble() : null;

    return CardModel(
      id: id,
      localId: json['localId']?.toString(),
      name: name,
      setId: setMap['id']?.toString(),
      setName: setMap['name']?.toString(),
      rarity: json['rarity']?.toString() ?? 'Rare',
      cardType: cardType,
      imageUrl: imageUrl,
      priceUsd: priceUsd ?? priceRefUsd,
      priceEur: priceEur,
      priceIdr: priceIdr,
      priceRefUsd: priceRefUsd,
      priceSource: priceSource ?? 'tcgplayer',
      hasPrice: hasPrice,
      seededAt: DateTime.now().toUtc(),
    );
  }

  static void _sortCards(List<CardModel> cards, SortOrder sortOrder) {
    switch (sortOrder) {
      case SortOrder.expensiveFirst:
        cards.sort((a, b) {
          final pa = a.priceRefUsd ?? 0.0;
          final pb = b.priceRefUsd ?? 0.0;
          return pb.compareTo(pa);
        });
        break;
      case SortOrder.cheapestFirst:
        cards.sort((a, b) {
          final pa = a.priceRefUsd ?? double.infinity;
          final pb = b.priceRefUsd ?? double.infinity;
          return pa.compareTo(pb);
        });
        break;
      case SortOrder.nameAsc:
        cards.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
  }
}
