import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/core/theme/app_theme.dart';

class CategoryChipsBar extends StatefulWidget {
  final ValueChanged<String>? onCategorySelected;

  const CategoryChipsBar({super.key, this.onCategorySelected});

  @override
  State<CategoryChipsBar> createState() => _CategoryChipsBarState();
}

class _CategoryChipsBarState extends State<CategoryChipsBar> {
  String? _selectedCategory;

  static const List<_CategoryItem> _categories = [
    _CategoryItem('Podcasts', MingCute.mic_line),
    _CategoryItem('Romance', MingCute.heart_line),
    _CategoryItem('Feel good', MingCute.emoji_line),
    _CategoryItem('Workout', MingCute.run_line),
    _CategoryItem('Relax', Icons.spa_rounded),
    _CategoryItem('Energize', MingCute.lightning_line),
    _CategoryItem('Party', MingCute.music_2_line),
    _CategoryItem('Focus', Icons.psychology_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _categories[index];
          final isSelected = _selectedCategory == item.name;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              item.icon,
              size: 16,
              color: isSelected ? Colors.white : Default_Theme.primaryColor1,
            ),
            label: Text(item.name),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Default_Theme.primaryColor1,
            ),
            backgroundColor: Default_Theme.primaryColor1.withValues(alpha: 0.08),
            selectedColor: Default_Theme.accentColor2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? Default_Theme.accentColor2
                    : Default_Theme.primaryColor1.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            onSelected: (selected) {
              setState(() {
                _selectedCategory = selected ? item.name : null;
              });
              if (widget.onCategorySelected != null) {
                widget.onCategorySelected!(_selectedCategory ?? '');
              }
            },
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final IconData icon;

  const _CategoryItem(this.name, this.icon);
}
