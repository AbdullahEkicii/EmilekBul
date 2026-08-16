import 'package:flutter/material.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String questionCount;
  final String key; // Localization key for name
  final String descriptionKey; // Localization key for description
  final bool isWeeklyBonus;
  final int bonusMultiplier;

  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.key,
    required this.descriptionKey,
    this.questionCount = '5 soru',
    this.isWeeklyBonus = false,
    this.bonusMultiplier = 1,
  });
}
