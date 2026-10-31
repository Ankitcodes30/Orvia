import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/indian_browse_categories.dart';
import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class YearCollectionItem {
  final String title;
  final String query;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const YearCollectionItem({
    required this.title,
    required this.query,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

const List<YearCollectionItem> kYearCollections = [
  YearCollectionItem(
    title: 'Best of 2026',
    query: 'Latest 2026 Hindi Chartbusters',
    subtitle: 'Brand new releases & singles',
    icon: MingCute.sparkles_fill,
    accentColor: Color(0xFF9C27B0),
  ),
  YearCollectionItem(
    title: 'Best of 2025',
    query: 'Best of 2025 Hindi Hits',
    subtitle: 'Chart-toppers from last year',
    icon: MingCute.calendar_fill,
    accentColor: Color(0xFFE91E63),
  ),
  YearCollectionItem(
    title: 'Best of 90s',
    query: 'Best of 90s Bollywood Evergreen Hits',
    subtitle: 'Nostalgic golden era classics',
    icon: MingCute.headphone_fill,
    accentColor: Color(0xFFFF9800),
  ),
  YearCollectionItem(
    title: 'Best of 2000s',
    query: 'Best of 2000s Bollywood Melodies',
    subtitle: 'Timeless millennial anthems',
    icon: MingCute.disc_fill,
    accentColor: Color(0xFF009688),
  ),
];

class YearCollectionsSection extends StatelessWidget {
  final String pluginId;

  const YearCollectionsSection({super.key, required this.pluginId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Decades & Year Collections',
            style: Default_Theme.primaryTextStyle.merge(
              const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Default_Theme.primaryColor1,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 95,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: kYearCollections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = kYearCollections[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final catItem = IndianCategoryItem(
                    title: item.title,
                    query: item.query,
                    icon: item.icon,
                    accentColor: item.accentColor,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryDetailScreenLauncher(
                        category: catItem,
                        pluginId: pluginId,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.accentColor.withValues(alpha: 0.35),
                        item.accentColor.withValues(alpha: 0.12),
                        Default_Theme.themeColor,
                      ],
                    ),
                    border: Border.all(
                      color: item.accentColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, size: 20, color: item.accentColor),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Default_Theme.primaryColor1,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
