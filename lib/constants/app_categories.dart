import 'dart:math';
import 'package:flutter/material.dart';
import '../models/category_model.dart';

class AppCategories {
  // Standart / Temel Kategoriler
  static const List<CategoryItem> categories = [
    CategoryItem(
      name: 'Genel Kültür',
      icon: Icons.auto_awesome,
      color: Color(0xFFFF6B6B),
      description: 'Tarih, bilim, edebiyat',
      key: 'categories.general_culture',
      descriptionKey: 'categories.general_culture_desc',
    ),
    CategoryItem(
      name: 'Yemek Kültürü',
      icon: Icons.restaurant,
      color: Color(0xFFE67E22),
      description: 'Geleneksel lezzetler',
      key: 'categories.food',
      descriptionKey: 'categories.food_desc',
    ),
    CategoryItem(
      name: 'Coğrafya',
      icon: Icons.public,
      color: Color(0xFF45B7D1),
      description: 'Ülkeler, başkentler, kıtalar',
      key: 'categories.geography',
      descriptionKey: 'categories.geography_desc',
    ),
    CategoryItem(
      name: 'Futbol',
      icon: Icons.sports_soccer,
      color: Color(0xFF96CEB4),
      description: 'Takımlar, oyuncular',
      key: 'categories.football',
      descriptionKey: 'categories.football_desc',
    ),
    CategoryItem(
      name: 'Dini',
      icon: Icons.mosque,
      color: Color(0xFFFECA57),
      description: 'İslam tarihi ve kültürü',
      key: 'categories.religious',
      descriptionKey: 'categories.religious_desc',
    ),
    CategoryItem(
      name: 'Bilim',
      icon: Icons.science,
      color: Color(0xFF2980B9),
      description: 'Uzay, fizik, kimya',
      key: 'categories.science',
      descriptionKey: 'categories.science_desc',
    ),
    CategoryItem(
      name: 'Sinema ve Dizi',
      icon: Icons.movie_filter_rounded,
      color: Color(0xFFE91E63),
      description: 'Filmler, yönetmenler',
      key: 'categories.cinema',
      descriptionKey: 'categories.cinema_desc',
    ),
    CategoryItem(
      name: 'Tarih',
      icon: Icons.history_edu_rounded,
      color: Color(0xFF795548),
      description: 'Savaşlar ve liderler',
      key: 'categories.history',
      descriptionKey: 'categories.history_desc',
    ),
    CategoryItem(
      name: 'Magazin',
      icon: Icons.menu_book,
      color: Color(0xFF8E44AD),
      description: 'Ünlüler ve magazin',
      key: 'categories.magazine',
      descriptionKey: 'categories.magazine_desc',
    ),
    CategoryItem(
      name: 'Müzik',
      icon: Icons.music_note,
      color: Color(0xFFF1C40F),
      description: 'Şarkılar ve sanatçılar',
      key: 'categories.music',
      descriptionKey: 'categories.music_desc',
    ),
  ];

  // 12 Özel / Dönüşümlü Bonus Kategorisi Havuzu (2X Puan & Jeton)
  static const List<CategoryItem> bonusPoolCategories = [
    CategoryItem(
      name: 'Uzay ve Evren',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFF7C4DFF),
      description: 'Gezegenler, karadelikler, astrofizik',
      key: 'categories.space',
      descriptionKey: 'categories.space_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Mitoloji ve Efsaneler',
      icon: Icons.castle_rounded,
      color: Color(0xFFFF9F43),
      description: 'Yunan, İskandinav, Mısır mitleri',
      key: 'categories.mythology',
      descriptionKey: 'categories.mythology_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Antik Uygarlıklar',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFC89666),
      description: 'Piramitler, Roma, Maya ve kayıp kentler',
      key: 'categories.ancient',
      descriptionKey: 'categories.ancient_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Video Oyunları & Espor',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF00D2D3),
      description: 'Efsane oyunlar, konsollar, karakterler',
      key: 'categories.gaming',
      descriptionKey: 'categories.gaming_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Dünya Mutfakları',
      icon: Icons.ramen_dining_rounded,
      color: Color(0xFFFF6B81),
      description: 'İtalyan, Asya, Meksika ve lezzet rotaları',
      key: 'categories.world_cuisine',
      descriptionKey: 'categories.world_cuisine_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Dünya Harikaları & Doğa',
      icon: Icons.landscape_rounded,
      color: Color(0xFF10AC84),
      description: 'Volkanlar, şelaleler, tabiat harikaları',
      key: 'categories.nature_wonders',
      descriptionKey: 'categories.nature_wonders_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Çizgi Roman & Anime',
      icon: Icons.palette_rounded,
      color: Color(0xFFFF5252),
      description: 'Süper kahramanlar, mangalar ve evrenler',
      key: 'categories.anime_comics',
      descriptionKey: 'categories.anime_comics_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Felsefe & Düşünce',
      icon: Icons.psychology_rounded,
      color: Color(0xFF5F27CD),
      description: 'Büyük düşünürler, ahlak ve fikir akımları',
      key: 'categories.philosophy',
      descriptionKey: 'categories.philosophy_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Yapay Zeka & Gelecek',
      icon: Icons.memory_rounded,
      color: Color(0xFF0ABDE3),
      description: 'Yapay zeka, siber teknoloji ve robotik',
      key: 'categories.ai_tech',
      descriptionKey: 'categories.ai_tech_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Doğa ve Vahşi Yaşam',
      icon: Icons.pets_rounded,
      color: Color(0xFF2ED573),
      description: 'Hayvanlar alemi, nadir türler ve eko-yaşam',
      key: 'categories.wildlife',
      descriptionKey: 'categories.wildlife_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Klasik Sanat & Mimari',
      icon: Icons.museum_rounded,
      color: Color(0xFFEE5253),
      description: 'Rönesans, tablolar, heykeller ve yapılar',
      key: 'categories.art_architecture',
      descriptionKey: 'categories.art_architecture_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
    CategoryItem(
      name: 'Edebiyat & Başyapıtlar',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF54A0FF),
      description: 'Dünya klasikleri, şiirler ve kült yazarlar',
      key: 'categories.literature',
      descriptionKey: 'categories.literature_desc',
      isWeeklyBonus: true,
      bonusMultiplier: 2,
    ),
  ];

  /// Her hafta deterministik olarak 12 özel kategoriden 3 tanesini aktif bonus kategori olarak seçer
  static List<CategoryItem> getWeeklyBonusCategories() {
    final now = DateTime.now();
    // 7 günlük hafta döngüsü indeksi (Deterministik)
    final epochDays = now.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
    final weekSeed = epochDays ~/ 7;

    final random = Random(weekSeed);
    final List<CategoryItem> shuffled = List.from(bonusPoolCategories);
    shuffled.shuffle(random);

    return shuffled.take(3).toList();
  }

  /// Verilen kategorinin aktif bir haftalık 2X bonus kategori olup olmadığını döner
  static bool isCategoryWeeklyBonus(String categoryName) {
    final activeBonusList = getWeeklyBonusCategories();
    return activeBonusList.any((cat) => cat.name == categoryName);
  }

  /// Verilen kategori isminin çeviri anahtarını (key) döner
  static String getCategoryKey(String categoryName) {
    final all = [...categories, ...bonusPoolCategories];
    final match = all.where((c) => c.name.toLowerCase() == categoryName.toLowerCase());
    if (match.isNotEmpty) {
      return match.first.key;
    }
    return '';
  }
}
