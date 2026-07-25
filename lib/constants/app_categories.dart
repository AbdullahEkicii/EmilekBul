import 'package:flutter/material.dart';
import '../models/category_model.dart';

class AppCategories {
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
}
