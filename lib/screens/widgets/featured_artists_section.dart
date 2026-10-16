import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:flutter/material.dart';

class VerifiedArtistData {
  final String id;
  final String name;
  final String imageUrl;

  const VerifiedArtistData({
    required this.id,
    required this.name,
    required this.imageUrl,
  });
}

const List<VerifiedArtistData> kFeaturedIndianArtists = [
  VerifiedArtistData(
    id: '459320',
    name: 'Arijit Singh',
    imageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '455130',
    name: 'Shreya Ghoshal',
    imageUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '456269',
    name: 'A. R. Rahman',
    imageUrl: 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '455109',
    name: 'Lata Mangeshkar',
    imageUrl: 'https://c.saavncdn.com/artists/Lata_Mangeshkar_004_20230623105323_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '455144',
    name: 'Kishore Kumar',
    imageUrl: 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '455125',
    name: 'Sonu Nigam',
    imageUrl: 'https://c.saavncdn.com/artists/Sonu_Nigam_003_20260813182013_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '455142',
    name: 'Kumar Sanu',
    imageUrl: 'https://c.saavncdn.com/artists/Kumar_Sanu_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '464932',
    name: 'Neha Kakkar',
    imageUrl: 'https://c.saavncdn.com/artists/Neha_Kakkar_007_20241212115832_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '456863',
    name: 'Badshah',
    imageUrl: 'https://c.saavncdn.com/artists/Badshah_006_20241118064015_500x500.jpg',
  ),
  VerifiedArtistData(
    id: '5892721',
    name: 'Jaya Kishori',
    imageUrl: 'https://c.saavncdn.com/artists/Jaya_Kishori_000_20250527084717_500x500.jpg',
  ),
];

class FeaturedArtistsSection extends StatelessWidget {
  final String pluginId;

  const FeaturedArtistsSection({super.key, required this.pluginId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Iconic Indian Artists',
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
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: kFeaturedIndianArtists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final artist = kFeaturedIndianArtists[index];
              return InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  final summary = ArtistSummary(
                    id: artist.id,
                    name: artist.name,
                    thumbnail: Artwork(
                      url: artist.imageUrl,
                      urlHigh: artist.imageUrl,
                      layout: ImageLayout.square,
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtistView(
                        artist: summary,
                        pluginId: pluginId,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Default_Theme.accentColor2.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: LoadImageCached(
                          imageUrl: artist.imageUrl,
                          fallbackUrl: artist.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 95,
                      child: Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ).merge(Default_Theme.secondoryTextStyle),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
