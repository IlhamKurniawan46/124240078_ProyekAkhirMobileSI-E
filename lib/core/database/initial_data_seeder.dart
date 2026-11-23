import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../models/card_model.dart';
import '../models/listing_model.dart';
import '../models/release_event_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import 'hive_database.dart';

/// Mengisi data awal (seed) ke dalam 10 Hive Box saat aplikasi pertama kali dijalankan.
/// Mencakup:
/// 1. Akun demo utama (`trainer_ash` / `password123`)
/// 2. 10 akun penjual di 10 kota besar Indonesia
/// 3. Katalog 24 kartu Pokémon TCG berharga dari 4 set utama (`swsh3`, `swsh7`, `sv01`, `sv05`)
/// 4. 15 listing pasar aktif lengkap dengan koordinat GPS di 10 kota Indonesia (untuk Pasar & Peta LBS)
/// 5. Koleksi Binder awal, Watchlist awal, Riwayat Transaksi awal, Kurs awal, dan 3 Event Rilis.
class InitialDataSeeder {
  InitialDataSeeder._();

  static const String demoUserId = 'user-ash-001';
  static const String demoUsername = 'trainer_ash';
  static const String demoPassword = 'password123';

  /// Hash password sederhana satu baris dengan SHA-256 (paket `crypto`).
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Jalankan seeding jika belum pernah di-seed (`is_seeded != true`) atau jika `force == true`.
  static Future<void> seedIfNeeded({bool force = false}) async {
    final isSeeded =
        HiveDatabase.settingsBox.get('is_seeded', defaultValue: false) == true;
    if (isSeeded && !force) return;

    final now = DateTime.now().toUtc();
    final defaultPassHash = hashPassword(demoPassword);

    // 1. Seed Cache Kurs Awal (Frankfurter ECB Baseline)
    await HiveDatabase.currencyBox.put('usd_rates', {
      'usd_to_idr': 16500.0,
      'usd_to_eur': 0.92,
      'usd_to_jpy': 154.5,
      'ecb_date': '2026-10-24',
      'updated_at': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
    });

    // 2. Seed Akun Demo Utama + 10 Penjual di 10 Kota Indonesia
    final users = <Map<String, dynamic>>[
      {
        ...UserModel(
          id: demoUserId,
          username: demoUsername,
          email: 'ash@holodex.id',
          balanceIdr: 2500000.0,
          whatsappNumber: '6281234567890',
          createdAt: now.subtract(const Duration(days: 30)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-jkt-01',
          username: 'misty_cards',
          email: 'misty@holodex.id',
          balanceIdr: 1850000.0,
          whatsappNumber: '6281290001111',
          createdAt: now.subtract(const Duration(days: 25)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-bdg-02',
          username: 'brock_pewter',
          email: 'brock@holodex.id',
          balanceIdr: 1400000.0,
          whatsappNumber: '6281290002222',
          createdAt: now.subtract(const Duration(days: 24)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-sby-03',
          username: 'cynthia_sinnoh',
          email: 'cynthia@holodex.id',
          balanceIdr: 3200000.0,
          whatsappNumber: '6281290003333',
          createdAt: now.subtract(const Duration(days: 22)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-yog-04',
          username: 'lance_dragon',
          email: 'lance@holodex.id',
          balanceIdr: 2100000.0,
          whatsappNumber: '6281290004444',
          createdAt: now.subtract(const Duration(days: 20)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-smg-05',
          username: 'steven_stone',
          email: 'steven@holodex.id',
          balanceIdr: 1750000.0,
          whatsappNumber: '6281290005555',
          createdAt: now.subtract(const Duration(days: 19)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-mdn-06',
          username: 'leon_galar',
          email: 'leon@holodex.id',
          balanceIdr: 2900000.0,
          whatsappNumber: '6281290006666',
          createdAt: now.subtract(const Duration(days: 18)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-mks-07',
          username: 'diantha_kalos',
          email: 'diantha@holodex.id',
          balanceIdr: 1600000.0,
          whatsappNumber: '6281290007777',
          createdAt: now.subtract(const Duration(days: 16)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-dps-08',
          username: 'professor_oak',
          email: 'oak@holodex.id',
          balanceIdr: 4500000.0,
          whatsappNumber: '6281290008888',
          createdAt: now.subtract(const Duration(days: 15)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-mlg-09',
          username: 'red_pallet',
          email: 'red@holodex.id',
          balanceIdr: 3100000.0,
          whatsappNumber: '6281290009999',
          createdAt: now.subtract(const Duration(days: 14)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
      {
        ...UserModel(
          id: 'seller-bpp-10',
          username: 'blue_viridian',
          email: 'blue@holodex.id',
          balanceIdr: 1950000.0,
          whatsappNumber: '6281290001010',
          createdAt: now.subtract(const Duration(days: 12)),
        ).toMap(),
        'password_hash': defaultPassHash,
      },
    ];

    for (final u in users) {
      await HiveDatabase.usersBox.put(u['id'] as String, u);
    }

    // 3. Seed Katalog 24 Kartu Pokémon TCG Berharga (4 Set Utama)
    final seededCards = _buildInitialCards(now);
    final cardMapById = <String, CardModel>{};
    for (final card in seededCards) {
      cardMapById[card.id] = card;
      await HiveDatabase.cardsBox.put(card.id, card.toMap());
    }

    // 4. Seed 15 Listing Pasar Aktif Berkoordinat GPS di 10 Kota Indonesia
    final listings = _buildInitialListings(now, cardMapById);
    for (final listing in listings) {
      await HiveDatabase.listingsBox.put(listing.id, listing.toMap());
    }

    // 5. Seed Binder Koleksi Saya untuk trainer_ash (2 kartu hasil beli pasar)
    final initialCollectionCardIds = ['swsh3-19', 'sv01-81'];
    for (final cid in initialCollectionCardIds) {
      final key = '${demoUserId}_$cid';
      await HiveDatabase.collectionsBox.put(key, {
        'id': key,
        'user_id': demoUserId,
        'card_id': cid,
        'acquired_via': 'purchase',
        'acquired_at':
            now.subtract(const Duration(days: 4)).millisecondsSinceEpoch,
      });
    }

    // 6. Seed Watchlist untuk trainer_ash (2 kartu incaran, 1 target harga tercapai)
    final watchlistSeed = [
      {
        'id': '${demoUserId}_swsh7-215',
        'user_id': demoUserId,
        'card_id': 'swsh7-215', // Umbreon VMAX
        'alert_price_idr': 15000000.0, // Target tercapai
        'added_at': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      },
      {
        'id': '${demoUserId}_sv05-196',
        'user_id': demoUserId,
        'card_id': 'sv05-196', // Raging Bolt ex
        'alert_price_idr': 600000.0,
        'added_at': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      },
    ];
    for (final w in watchlistSeed) {
      await HiveDatabase.watchlistBox.put(w['id'] as String, w);
    }

    // 7. Seed 1 Riwayat Transaksi Selesai untuk trainer_ash
    final txCard = cardMapById['swsh3-19'];
    final sampleTx = TransactionModel(
      id: 'tx-demo-001',
      listingId: 'listing-past-001',
      buyerId: demoUserId,
      sellerId: 'seller-jkt-01',
      cardId: 'swsh3-19',
      priceIdr: 420000.0,
      createdAt: now.subtract(const Duration(days: 4)),
      card: txCard,
      buyerUsername: demoUsername,
      sellerUsername: 'misty_cards',
      isBuyer: true,
    );
    await HiveDatabase.transactionsBox.put(sampleTx.id, sampleTx.toMap());

    // 8. Seed 3 Jadwal Event Rilis & Turnamen
    final events = ReleaseEventModel.defaultEvents
        .map((e) => e.toJson())
        .toList();
    await HiveDatabase.settingsBox.put('release_events', events);

    // 9. Tandai seeding selesai & set mata uang default IDR
    await HiveDatabase.settingsBox.put('selected_currency', 'IDR');
    await HiveDatabase.settingsBox.put('is_seeded', true);
  }

  static List<CardModel> _buildInitialCards(DateTime now) {
    CardModel makeCard({
      required String id,
      required String localId,
      required String name,
      required String setId,
      required String setName,
      required String rarity,
      required String cardType,
      required String imageUrl,
      required double priceUsd,
    }) {
      final priceEur = double.parse((priceUsd * 0.92).toStringAsFixed(2));
      final priceIdr = (priceUsd * 16500.0).roundToDouble();
      return CardModel(
        id: id,
        localId: localId,
        name: name,
        setId: setId,
        setName: setName,
        rarity: rarity,
        cardType: cardType,
        imageUrl: imageUrl,
        priceUsd: priceUsd,
        priceEur: priceEur,
        priceIdr: priceIdr,
        priceRefUsd: priceUsd,
        priceSource: 'tcgplayer',
        hasPrice: true,
        seededAt: now,
      );
    }

    return [
      // Set 1: swsh7 (Evolving Skies)
      makeCard(
        id: 'swsh7-215',
        localId: '215',
        name: 'Umbreon VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        cardType: 'Darkness',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh7/215',
        priceUsd: 890.00,
      ),
      makeCard(
        id: 'swsh7-218',
        localId: '218',
        name: 'Rayquaza VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        cardType: 'Dragon',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh7/218',
        priceUsd: 445.00,
      ),
      makeCard(
        id: 'swsh7-209',
        localId: '209',
        name: 'Glaceon VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        cardType: 'Water',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh7/209',
        priceUsd: 215.00,
      ),
      makeCard(
        id: 'swsh7-205',
        localId: '205',
        name: 'Leafeon VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        cardType: 'Grass',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh7/205',
        priceUsd: 260.00,
      ),
      makeCard(
        id: 'swsh7-212',
        localId: '212',
        name: 'Sylveon VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        cardType: 'Psychic',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh7/212',
        priceUsd: 210.00,
      ),
      makeCard(
        id: 'swsh7-192',
        localId: '192',
        name: 'Dragonite V',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Ultra Rare',
        cardType: 'Dragon',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh7/192',
        priceUsd: 155.00,
      ),

      // Set 2: swsh3 (Darkness Ablaze)
      makeCard(
        id: 'swsh3-20',
        localId: '20',
        name: 'Charizard VMAX',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Ultra Rare',
        cardType: 'Fire',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh3/20',
        priceUsd: 38.50,
      ),
      makeCard(
        id: 'swsh3-19',
        localId: '19',
        name: 'Charizard V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Holo Rare V',
        cardType: 'Fire',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh3/19',
        priceUsd: 8.50,
      ),
      makeCard(
        id: 'swsh3-117',
        localId: '117',
        name: 'Eternatus VMAX',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Ultra Rare',
        cardType: 'Darkness',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh3/117',
        priceUsd: 6.20,
      ),
      makeCard(
        id: 'swsh3-1',
        localId: '1',
        name: 'Butterfree V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Holo Rare V',
        cardType: 'Grass',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh3/1',
        priceUsd: 2.40,
      ),
      makeCard(
        id: 'swsh3-104',
        localId: '104',
        name: 'Crobat V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Holo Rare V',
        cardType: 'Darkness',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh3/104',
        priceUsd: 3.10,
      ),
      makeCard(
        id: 'swsh3-189',
        localId: '189',
        name: 'Mew V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Ultra Rare',
        cardType: 'Psychic',
        imageUrl: 'https://assets.tcgdex.net/en/swsh/swsh3/189',
        priceUsd: 14.80,
      ),

      // Set 3: sv01 (Scarlet & Violet)
      makeCard(
        id: 'sv01-244',
        localId: '244',
        name: 'Miraidon ex',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Special Illustration Rare',
        cardType: 'Lightning',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv01/244',
        priceUsd: 26.50,
      ),
      makeCard(
        id: 'sv01-245',
        localId: '245',
        name: 'Gardevoir ex',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Special Illustration Rare',
        cardType: 'Psychic',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv01/245',
        priceUsd: 34.00,
      ),
      makeCard(
        id: 'sv01-247',
        localId: '247',
        name: 'Koraidon ex',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Special Illustration Rare',
        cardType: 'Fighting',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv01/247',
        priceUsd: 19.20,
      ),
      makeCard(
        id: 'sv01-81',
        localId: '081',
        name: 'Miraidon ex (Double Rare)',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Double Rare',
        cardType: 'Lightning',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv01/081',
        priceUsd: 4.50,
      ),
      makeCard(
        id: 'sv01-86',
        localId: '086',
        name: 'Gardevoir ex (Double Rare)',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Double Rare',
        cardType: 'Psychic',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv01/086',
        priceUsd: 3.90,
      ),
      makeCard(
        id: 'sv01-198',
        localId: '198',
        name: 'Ralts (Illustration Rare)',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Illustration Rare',
        cardType: 'Psychic',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv01/198',
        priceUsd: 16.00,
      ),

      // Set 4: sv05 (Temporal Forces)
      makeCard(
        id: 'sv05-208',
        localId: '208',
        name: 'Raging Bolt ex (SIR)',
        setId: 'sv05',
        setName: 'Temporal Forces',
        rarity: 'Special Illustration Rare',
        cardType: 'Dragon',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv05/208',
        priceUsd: 88.00,
      ),
      makeCard(
        id: 'sv05-205',
        localId: '205',
        name: 'Walking Wake ex (SIR)',
        setId: 'sv05',
        setName: 'Temporal Forces',
        rarity: 'Special Illustration Rare',
        cardType: 'Water',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv05/205',
        priceUsd: 54.00,
      ),
      makeCard(
        id: 'sv05-206',
        localId: '206',
        name: 'Iron Crown ex (SIR)',
        setId: 'sv05',
        setName: 'Temporal Forces',
        rarity: 'Special Illustration Rare',
        cardType: 'Psychic',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv05/206',
        priceUsd: 68.50,
      ),
      makeCard(
        id: 'sv05-204',
        localId: '204',
        name: 'Gouging Fire ex (SIR)',
        setId: 'sv05',
        setName: 'Temporal Forces',
        rarity: 'Special Illustration Rare',
        cardType: 'Fire',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv05/204',
        priceUsd: 49.00,
      ),
      makeCard(
        id: 'sv05-196',
        localId: '196',
        name: 'Raging Bolt ex (Ultra Rare)',
        setId: 'sv05',
        setName: 'Temporal Forces',
        rarity: 'Ultra Rare',
        cardType: 'Dragon',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv05/196',
        priceUsd: 15.50,
      ),
      makeCard(
        id: 'sv05-123',
        localId: '123',
        name: 'Gastly (Illustration Rare)',
        setId: 'sv05',
        setName: 'Temporal Forces',
        rarity: 'Illustration Rare',
        cardType: 'Darkness',
        imageUrl: 'https://assets.tcgdex.net/en/sv/sv05/123',
        priceUsd: 32.00,
      ),
    ];
  }

  static List<ListingModel> _buildInitialListings(
    DateTime now,
    Map<String, CardModel> cards,
  ) {
    return [
      // 1. Jakarta Pusat (Monas / Thamrin)
      ListingModel(
        id: 'listing-001',
        cardId: 'swsh3-20',
        sellerId: 'seller-jkt-01',
        sellerUsername: 'misty_cards',
        priceIdr: 625000.0,
        condition: 'near_mint',
        description:
            'Charizard VMAX Darkness Ablaze pull sendiri langsung masuk sleeve + toploader. Siap COD sekitar Grand Indonesia / Monas.',
        lat: -6.1754,
        lng: 106.8272,
        status: 'active',
        createdAt: now.subtract(const Duration(hours: 4)),
        card: cards['swsh3-20'],
      ),
      // 2. Jakarta Selatan (Senayan)
      ListingModel(
        id: 'listing-002',
        cardId: 'sv01-244',
        sellerId: 'seller-jkt-01',
        sellerUsername: 'misty_cards',
        priceIdr: 430000.0,
        condition: 'mint',
        description:
            'Miraidon ex Special Illustration Rare centering rapi 50:50. COD Senayan City atau FX Sudirman.',
        lat: -6.2253,
        lng: 106.7997,
        status: 'active',
        createdAt: now.subtract(const Duration(hours: 8)),
        card: cards['sv01-244'],
      ),
      // 3. Bandung (Braga)
      ListingModel(
        id: 'listing-003',
        cardId: 'sv01-245',
        sellerId: 'seller-bdg-02',
        sellerUsername: 'brock_pewter',
        priceIdr: 550000.0,
        condition: 'mint',
        description:
            'Gardevoir ex SIR mulus tanpa whitening. Bisa cek fisik di Braga CityWalk Bandung.',
        lat: -6.9175,
        lng: 107.6191,
        status: 'active',
        createdAt: now.subtract(const Duration(hours: 12)),
        card: cards['sv01-245'],
      ),
      // 4. Bandung (Dago)
      ListingModel(
        id: 'listing-004',
        cardId: 'swsh3-189',
        sellerId: 'seller-bdg-02',
        sellerUsername: 'brock_pewter',
        priceIdr: 235000.0,
        condition: 'near_mint',
        description:
            'Mew V Full Art Darkness Ablaze koleksi pribadi. COD Dago / Dipatiukur Bandung.',
        lat: -6.8904,
        lng: 107.6130,
        status: 'active',
        createdAt: now.subtract(const Duration(hours: 18)),
        card: cards['swsh3-189'],
      ),
      // 5. Surabaya (Tunjungan)
      ListingModel(
        id: 'listing-005',
        cardId: 'swsh7-218',
        sellerId: 'seller-sby-03',
        sellerUsername: 'cynthia_sinnoh',
        priceIdr: 7200000.0,
        condition: 'mint',
        description:
            'Rayquaza VMAX Alt Art Evolving Skies grail card. Hanya melayani COD di Tunjungan Plaza Surabaya.',
        lat: -7.2575,
        lng: 112.7521,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 1)),
        card: cards['swsh7-218'],
      ),
      // 6. Yogyakarta (Malioboro)
      ListingModel(
        id: 'listing-006',
        cardId: 'sv05-208',
        sellerId: 'seller-yog-04',
        sellerUsername: 'lance_dragon',
        priceIdr: 1420000.0,
        condition: 'mint',
        description:
            'Raging Bolt ex SIR Temporal Forces foil sangat tajam. COD Malioboro Mall / Tugu Jogja.',
        lat: -7.7956,
        lng: 110.3695,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        card: cards['sv05-208'],
      ),
      // 7. Yogyakarta (Sleman / UGM)
      ListingModel(
        id: 'listing-007',
        cardId: 'swsh7-192',
        sellerId: 'seller-yog-04',
        sellerUsername: 'lance_dragon',
        priceIdr: 2450000.0,
        condition: 'near_mint',
        description:
            'Dragonite V Alt Art Evolving Skies. COD Pakuwon Mall Jogja atau seputaran Kampus UGM.',
        lat: -7.7599,
        lng: 110.3991,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 1, hours: 9)),
        card: cards['swsh7-192'],
      ),
      // 8. Semarang (Simpang Lima)
      ListingModel(
        id: 'listing-008',
        cardId: 'sv05-206',
        sellerId: 'seller-smg-05',
        sellerUsername: 'steven_stone',
        priceIdr: 1100000.0,
        condition: 'mint',
        description:
            'Iron Crown ex SIR Temporal Forces kondisi pack fresh. COD Mall Ciputra Simpang Lima Semarang.',
        lat: -6.9904,
        lng: 110.4229,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 2)),
        card: cards['sv05-206'],
      ),
      // 9. Medan (Merdeka Walk)
      ListingModel(
        id: 'listing-009',
        cardId: 'sv05-205',
        sellerId: 'seller-mdn-06',
        sellerUsername: 'leon_galar',
        priceIdr: 875000.0,
        condition: 'near_mint',
        description:
            'Walking Wake ex SIR Temporal Forces. Siap COD di Sun Plaza / Merdeka Walk Medan.',
        lat: 3.5952,
        lng: 98.6722,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 2, hours: 5)),
        card: cards['sv05-205'],
      ),
      // 10. Makassar (Pantai Losari)
      ListingModel(
        id: 'listing-010',
        cardId: 'swsh7-212',
        sellerId: 'seller-mks-07',
        sellerUsername: 'diantha_kalos',
        priceIdr: 3400000.0,
        condition: 'mint',
        description:
            'Sylveon VMAX Alt Art Evolving Skies. COD Trans Studio Mall Makassar.',
        lat: -5.1477,
        lng: 119.4327,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 2, hours: 10)),
        card: cards['swsh7-212'],
      ),
      // 11. Denpasar Bali (Renon)
      ListingModel(
        id: 'listing-011',
        cardId: 'swsh7-215',
        sellerId: 'seller-dps-08',
        sellerUsername: 'professor_oak',
        priceIdr: 14500000.0,
        condition: 'mint',
        description:
            'Moonbreon (Umbreon VMAX Alt Art) koleksi terbaik. COD di Level 21 Mall Denpasar atau Beachwalk Kuta.',
        lat: -8.6705,
        lng: 115.2126,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 3)),
        card: cards['swsh7-215'],
      ),
      // 12. Malang (Ijen)
      ListingModel(
        id: 'listing-012',
        cardId: 'sv05-123',
        sellerId: 'seller-mlg-09',
        sellerUsername: 'red_pallet',
        priceIdr: 515000.0,
        condition: 'near_mint',
        description:
            'Gastly Illustration Rare Temporal Forces artwork populer. COD Mall Olympic Garden (MOG) Malang.',
        lat: -7.9778,
        lng: 112.6239,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 3, hours: 6)),
        card: cards['sv05-123'],
      ),
      // 13. Balikpapan
      ListingModel(
        id: 'listing-013',
        cardId: 'sv05-204',
        sellerId: 'seller-bpp-10',
        sellerUsername: 'blue_viridian',
        priceIdr: 790000.0,
        condition: 'excellent',
        description:
            'Gouging Fire ex SIR Temporal Forces. COD Pentacity Mall Balikpapan Superblock.',
        lat: -1.2750,
        lng: 116.8584,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 4)),
        card: cards['sv05-204'],
      ),
      // 14. Jakarta Utara (Kelapa Gading)
      ListingModel(
        id: 'listing-014',
        cardId: 'sv01-198',
        sellerId: 'seller-jkt-01',
        sellerUsername: 'misty_cards',
        priceIdr: 255000.0,
        condition: 'near_mint',
        description:
            'Ralts Illustration Rare Scarlet & Violet Base. COD Mall Kelapa Gading.',
        lat: -6.1574,
        lng: 106.9082,
        status: 'active',
        createdAt: now.subtract(const Duration(days: 4, hours: 4)),
        card: cards['sv01-198'],
      ),
      // 15. Listing Aktif Milik trainer_ash Sendiri (Siap Uji Fitur Edit Listing & Batalkan!)
      ListingModel(
        id: 'listing-ash-015',
        cardId: 'sv01-86',
        sellerId: demoUserId,
        sellerUsername: demoUsername,
        priceIdr: 75000.0,
        condition: 'near_mint',
        description:
            'Gardevoir ex Double Rare siap main deck kompetitif. Bisa dicoba fitur Edit Listing atau Batalkan di sini!',
        lat: -6.1944,
        lng: 106.8229,
        status: 'active',
        createdAt: now.subtract(const Duration(hours: 2)),
        card: cards['sv01-86'],
      ),
    ];
  }
}
