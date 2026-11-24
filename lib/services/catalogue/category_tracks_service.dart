import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';

class MoodCardItem {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String searchQuery;
  final List<Track> fallbackTracks;

  const MoodCardItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.searchQuery,
    this.fallbackTracks = const [],
  });
}

abstract class MoodSection {
  final String title;
  const MoodSection({required this.title});
}

class MoodCardSection extends MoodSection {
  final String? tag;
  final List<MoodCardItem> items;

  const MoodCardSection({
    this.tag,
    required super.title,
    required this.items,
  });
}

class MoodSongGridSection extends MoodSection {
  final List<Track> tracks;

  const MoodSongGridSection({
    required super.title,
    required this.tracks,
  });
}

class CategoryTracksService {
  static const String _saavnPluginId = 'content-resolver.bloomfactory.saavn';
  static const String _ytPluginId = 'content-resolver.bloomfactory.ytvideo';

  static Track _sTrack({
    required String rawId,
    required String title,
    required String artist,
    required String album,
    required String imgUrl,
    int durationSec = 240,
  }) {
    final artwork = Artwork(
      url: imgUrl,
      urlLow: imgUrl,
      urlHigh: imgUrl,
      layout: ImageLayout.square,
    );
    return Track(
      id: '$_saavnPluginId::$rawId',
      title: title,
      artists: [ArtistSummary(id: '', name: artist, thumbnail: artwork)],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: artwork,
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: artwork,
      isExplicit: false,
    );
  }

  static Track _ytTrack({
    required String videoId,
    required String title,
    required String artist,
    required String album,
    required String imgUrl,
    int durationSec = 240,
  }) {
    final artwork = Artwork(
      url: imgUrl,
      urlLow: imgUrl,
      urlHigh: imgUrl,
      layout: ImageLayout.square,
    );
    return Track(
      id: '$_ytPluginId::$videoId',
      title: title,
      artists: [ArtistSummary(id: '', name: artist, thumbnail: artwork)],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: artwork,
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: artwork,
      url: 'https://www.youtube.com/watch?v=$videoId',
      isExplicit: false,
    );
  }

  // ── Verified Track Collections ──

  static final List<Track> _romanceTracks = [
    _sTrack(
      rawId: 'GQlvs79S',
      title: 'Naino Ne Baandhi',
      artist: 'Yasser Desai, Arko',
      album: 'Gold',
      imgUrl: 'https://c.saavncdn.com/971/Gold-Hindi-2018-20250617065303-500x500.webp',
      durationSec: 241,
    ),
    _sTrack(
      rawId: 'fme85vQj',
      title: 'Sab Tera',
      artist: 'Armaan Malik, Shraddha Kapoor',
      album: 'Baaghi',
      imgUrl: 'https://c.saavncdn.com/944/Baaghi-Hindi-2016-20220420171003-500x500.webp',
      durationSec: 228,
    ),
    _sTrack(
      rawId: '3x-IwBwd',
      title: 'Soch Na Sake',
      artist: 'Arijit Singh, Tulsi Kumar',
      album: 'Airlift',
      imgUrl: 'https://c.saavncdn.com/451/Airlift-Hindi-2015-500x500.jpg',
      durationSec: 287,
    ),
    _ytTrack(
      videoId: 'gIOea2pgfIo',
      title: 'Tere Sang Yaara',
      artist: 'Atif Aslam, Arko',
      album: 'Rustom',
      imgUrl: 'https://i.ytimg.com/vi/gIOea2pgfIo/hqdefault.jpg',
      durationSec: 294,
    ),
    _sTrack(
      rawId: 'zIPKC8PK',
      title: 'Tum Se Hi',
      artist: 'Pritam, Mohit Chauhan',
      album: 'Jab We Met',
      imgUrl: 'https://c.saavncdn.com/223/Jab-We-Met-Hindi-2007-20231016162009-500x500.webp',
      durationSec: 321,
    ),
    _ytTrack(
      videoId: 'P8PWN1OmZOA',
      title: 'Tu Jaane Na',
      artist: 'Pritam, Atif Aslam',
      album: 'Ajab Prem Ki Ghazab Kahani',
      imgUrl: 'https://i.ytimg.com/vi/P8PWN1OmZOA/hqdefault.jpg',
      durationSec: 337,
    ),
    _sTrack(
      rawId: 'WCpI6Pg8',
      title: 'Ishq Bulaava',
      artist: 'Vishal & Shekhar, Sanam Puri',
      album: 'Hasee Toh Phasee',
      imgUrl: 'https://c.saavncdn.com/479/Hasee-Toh-Phasee-Hindi-2014-20260120201339-500x500.webp',
      durationSec: 303,
    ),
    _sTrack(
      rawId: '3zFgrvoE',
      title: 'Maiyya Mainu',
      artist: 'Sachet Tandon',
      album: 'Jersey',
      imgUrl: 'https://c.saavncdn.com/799/Jersey-Hindi-2021-20220412145401-500x500.webp',
      durationSec: 231,
    ),
    _ytTrack(
      videoId: 'Km5AQkh58DU',
      title: 'Tere Naina',
      artist: 'Shafqat Amanat Ali',
      album: 'My Name is Khan',
      imgUrl: 'https://i.ytimg.com/vi/Km5AQkh58DU/hqdefault.jpg',
      durationSec: 285,
    ),
    _sTrack(
      rawId: 'UuGteRjX',
      title: 'Main Rahoon Ya Na Rahoon',
      artist: 'Armaan Malik',
      album: 'Main Rahoon Ya Na Rahoon',
      imgUrl: 'https://c.saavncdn.com/395/Main-Rahoon-Ya-Na-Rahoon-Hindi-2015-500x500.jpg',
      durationSec: 310,
    ),
    _sTrack(
      rawId: 'w6nRvGId',
      title: 'Dil Se Dil Tak',
      artist: 'Akashdeep Sengupta, Laqshay Kapoor',
      album: 'Bawaal',
      imgUrl: 'https://c.saavncdn.com/016/Bawaal-Hindi-2023-20230722214515-500x500.webp',
      durationSec: 301,
    ),
    _sTrack(
      rawId: 'bIAmZceU',
      title: 'I Am In Love',
      artist: 'Pritam, KK',
      album: 'Once Upon A Time In Mumbaai',
      imgUrl: 'https://c.saavncdn.com/512/Once-Upon-A-Time-In-Mumbaai-Hindi-2010-20241223141749-500x500.webp',
      durationSec: 285,
    ),
  ];

  static final List<Track> _relaxTracks = [
    _sTrack(
      rawId: 'X3JYs0TD',
      title: 'Paniyon Sa',
      artist: 'Tulsi Kumar, Rochak Kohli',
      album: 'Satyameva Jayate',
      imgUrl: 'https://c.saavncdn.com/495/World-Music-Day-Hindi-2025-20260217171350-500x500.webp',
      durationSec: 236,
    ),
    _sTrack(
      rawId: 'cli-P2pu',
      title: 'Arz Kiya Hai',
      artist: 'Anuv Jain',
      album: 'Coke Studio Bharat',
      imgUrl: 'https://c.saavncdn.com/504/Arz-Kiya-Hai-Coke-Studio-Bharat-Hindi-2025-20250818054005-500x500.webp',
      durationSec: 294,
    ),
    _sTrack(
      rawId: 'KvSHdENF',
      title: 'Aankhon Se Batana',
      artist: 'Dikshant',
      album: 'Indie Campus Chill Hits',
      imgUrl: 'https://c.saavncdn.com/084/Indie-Campus-Chill-Hits-Hindi-2024-20240627120630-500x500.webp',
      durationSec: 221,
    ),
    _ytTrack(
      videoId: '6g63m_8Z-xI',
      title: 'Phir aur kya chahiye || Instrumental cover',
      artist: 'A.K. MUSIC WORLD',
      album: 'Instrumental Discovery',
      imgUrl: 'https://i.ytimg.com/vi/6g63m_8Z-xI/hqdefault.jpg',
      durationSec: 270,
    ),
    _sTrack(
      rawId: 'PCOr94Xj',
      title: 'Pee Loon',
      artist: 'Mohit Chauhan, Pritam',
      album: 'Once Upon A Time In Mumbaai',
      imgUrl: 'https://c.saavncdn.com/106/Emraan-Hashmi-Hits-Hindi-2026-20260905191028-500x500.webp',
      durationSec: 285,
    ),
    _sTrack(
      rawId: '0rYr57cr',
      title: 'Saathiyaa',
      artist: 'Shreya Ghoshal, Ajay-Atul',
      album: 'Singham',
      imgUrl: 'https://c.saavncdn.com/470/Singham-Hindi-2011-20221211220044-500x500.webp',
      durationSec: 310,
    ),
    _sTrack(
      rawId: 'Xd9NQgRm',
      title: 'Jitni Dafa',
      artist: 'Yasser Desai',
      album: 'Parmanu',
      imgUrl: 'https://c.saavncdn.com/718/Parmanu-Hindi-2018-20250617070209-500x500.webp',
      durationSec: 222,
    ),
    _sTrack(
      rawId: '68Mzp1yU',
      title: 'Main Hoon Saath Tere',
      artist: 'Arijit Singh',
      album: 'Shaadi Mein Zaroor Aana',
      imgUrl: 'https://c.saavncdn.com/861/Shaadi-Mein-Zaroor-Aana-Hindi-2017-20171024101945-500x500.jpg',
      durationSec: 280,
    ),
    _sTrack(
      rawId: 'CakwGrU-',
      title: 'Tenu Na Bol Pawaan',
      artist: 'Yasser Desai, Jyotica Tangri',
      album: 'Behen Hogi Teri',
      imgUrl: 'https://c.saavncdn.com/128/Behen-Hogi-Teri-Hindi-2017-500x500.jpg',
      durationSec: 295,
    ),
  ];

  static final List<Track> _partyTracks = [
    _sTrack(
      rawId: 'pdAQnMhS',
      title: 'Soulmate',
      artist: 'Badshah, Arijit Singh',
      album: 'The Biggest Songs 2024',
      imgUrl: 'https://c.saavncdn.com/638/Arijit-Singh-X-Badshah-The-Biggest-Songs-2024-Hindi-2024-20240410215733-500x500.webp',
      durationSec: 214,
    ),
    _sTrack(
      rawId: 'B-Zsr1IJ',
      title: 'Suniyan Suniyan',
      artist: 'Juss, Mixsingh',
      album: 'Suniyan Suniyan',
      imgUrl: 'https://c.saavncdn.com/121/Suniyan-Suniyan-Punjabi-2024-20240415211002-500x500.webp',
      durationSec: 198,
    ),
    _sTrack(
      rawId: 'eW0aCCuD',
      title: 'Dil Se Dil Tak (Remix)',
      artist: 'Akashdeep Sengupta, Moodyboy',
      album: 'Bawaal Jhankar Beats',
      imgUrl: 'https://c.saavncdn.com/167/Bawaal-Re-Mastered-Jhankar-Beats-Hindi-2023-20231020141003-500x500.webp',
      durationSec: 299,
    ),
    _sTrack(
      rawId: 'AK3icrxP',
      title: 'Dil Meri Na Sune',
      artist: 'Sameer Khan, Himesh Reshammiya',
      album: 'Genius',
      imgUrl: 'https://c.saavncdn.com/994/Genius-Hindi-2018-20250728123019-500x500.webp',
      durationSec: 236,
    ),
    _ytTrack(
      videoId: 'pGuc4hPhiKw',
      title: 'Bin Tere (Remix)',
      artist: 'Vishal & Shekhar',
      album: 'I Hate Luv Storys',
      imgUrl: 'https://i.ytimg.com/vi/pGuc4hPhiKw/hqdefault.jpg',
      durationSec: 331,
    ),
    _sTrack(
      rawId: 'XGsFYSzP',
      title: 'Kali Kali Zulfon Ke',
      artist: 'Madhur Sharma',
      album: 'Sufi Romance',
      imgUrl: 'https://c.saavncdn.com/383/Sufi-Romance-Hindi-2025-20251106053812-500x500.webp',
      durationSec: 350,
    ),
  ];

  static final List<Track> _podcastBooksTracks = [
    _ytTrack(
      videoId: '2_9eX8k2T38',
      title: 'The Ranveer Show (TRS Hindi)',
      artist: 'Ranveer Allahbadia • 10M plays',
      album: 'Books & Insights',
      imgUrl: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&auto=format&fit=crop&q=80',
      durationSec: 3600,
    ),
    _ytTrack(
      videoId: 'G7P3q4g8988',
      title: 'Desi Crime Podcast - True Crime Stories',
      artist: 'Desi Studios • 4.2M plays',
      album: 'Books & Audio Stories',
      imgUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop&q=80',
      durationSec: 2800,
    ),
    _ytTrack(
      videoId: 'W7fM44ZkOAg',
      title: 'Akbar Birbal Classic Stories in Hindi',
      artist: 'Hindi Stories Hub • 1.5M plays',
      album: 'Books',
      imgUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&auto=format&fit=crop&q=80',
      durationSec: 1800,
    ),
    _ytTrack(
      videoId: 'nQ8L6F2sKjE',
      title: 'Panchatantra Ki Kahaniya Audio Book',
      artist: 'Katha Audio • 3.1M plays',
      album: 'Books',
      imgUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=500&auto=format&fit=crop&q=80',
      durationSec: 2400,
    ),
    _ytTrack(
      videoId: 'l3xO0m3U4lA',
      title: 'Historical Indian Stories & Legends',
      artist: 'History Katha • 850K plays',
      album: 'Books',
      imgUrl: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=500&auto=format&fit=crop&q=80',
      durationSec: 2100,
    ),
    _ytTrack(
      videoId: '5T6KjY_wK7Y',
      title: 'Mahabharat Insights Audio Podcast',
      artist: 'Epics Audio • 2.8M plays',
      album: 'Books',
      imgUrl: 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?w=500&auto=format&fit=crop&q=80',
      durationSec: 3200,
    ),
  ];

  static final List<Track> _podcastFictionTracks = [
    _ytTrack(
      videoId: 'k1eY5yG3r_Y',
      title: 'The Curse of Room No. 7 | Horror Audio Story',
      artist: 'Thane Horror Story • 1.2M plays',
      album: 'Fiction',
      imgUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&auto=format&fit=crop&q=80',
      durationSec: 1620,
    ),
    _ytTrack(
      videoId: 'dO-2M9dZ7iE',
      title: 'Radio Milan Audio Story | The Knight of Mystery',
      artist: 'Radio Milan • 780K plays',
      album: 'Fiction',
      imgUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
      durationSec: 2100,
    ),
    _ytTrack(
      videoId: 'jfKfPfyJRdk',
      title: 'Greeking Out Podcast | Mythological Adventures',
      artist: 'Nat Geo Kids • 950K plays',
      album: 'Fiction',
      imgUrl: 'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=500&auto=format&fit=crop&q=80',
      durationSec: 1800,
    ),
  ];

  static final List<Track> _focusTracks = [
    _ytTrack(
      videoId: 'jfKfPfyJRdk',
      title: 'Lofi Beats for Deep Focus & Study',
      artist: 'Lofi Girl • Ambient',
      album: 'Deep focus',
      imgUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
      durationSec: 3600,
    ),
    _ytTrack(
      videoId: 'WPni755-Krg',
      title: 'Classical Focus Solo Piano',
      artist: 'Classical Masters • Peaceful',
      album: 'Classical Focus',
      imgUrl: 'https://images.unsplash.com/photo-1520523839898-507127027d53?w=500&auto=format&fit=crop&q=80',
      durationSec: 3000,
    ),
    _ytTrack(
      videoId: 'RqzGzwTY-6w',
      title: 'Brown Noise for Pure Concentration',
      artist: 'Noise Therapy • 8 Hours',
      album: 'Brown Noise',
      imgUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
      durationSec: 3600,
    ),
    _ytTrack(
      videoId: 'nMfPqeZjc2c',
      title: 'White Noise Sound Masking',
      artist: 'Sleep Therapy • Continuous',
      album: 'White Noise',
      imgUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&auto=format&fit=crop&q=80',
      durationSec: 3600,
    ),
  ];

  static final List<Track> _sleepTracks = [
    _ytTrack(
      videoId: '1ZYbU82GVz4',
      title: 'Gentle Piano for Deep Peaceful Sleep',
      artist: 'The Chillest Piano • Sleep',
      album: 'Musical sleep',
      imgUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
      durationSec: 3600,
    ),
    _ytTrack(
      videoId: 'mPZkdNFkNps',
      title: 'Gentle Rain Sounds for Sleeping',
      artist: 'Nature Sounds Hub • Rain',
      album: 'Meditative sleep',
      imgUrl: 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=500&auto=format&fit=crop&q=80',
      durationSec: 3600,
    ),
    _sTrack(
      rawId: 'X3JYs0TD',
      title: 'Paniyon Sa (Acoustic Unplugged)',
      artist: 'Tulsi Kumar, Rochak Kohli',
      album: 'Sweet Dreams',
      imgUrl: 'https://c.saavncdn.com/495/World-Music-Day-Hindi-2025-20260217171350-500x500.webp',
      durationSec: 236,
    ),
    _sTrack(
      rawId: 'cli-P2pu',
      title: 'Arz Kiya Hai (Midnight Acoustic)',
      artist: 'Anuv Jain',
      album: 'Midnight Romance',
      imgUrl: 'https://c.saavncdn.com/504/Arz-Kiya-Hai-Coke-Studio-Bharat-Hindi-2025-20250818054005-500x500.webp',
      durationSec: 294,
    ),
  ];

  // ── Public API ──

  static List<Track> getTracksForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'romance':
        return _romanceTracks;
      case 'relax':
        return _relaxTracks;
      case 'party':
        return _partyTracks;
      case 'podcasts':
        return [..._podcastBooksTracks, ..._podcastFictionTracks];
      case 'focus':
        return _focusTracks;
      case 'sleep':
        return _sleepTracks;
      case 'energize':
      case 'workout':
        return _partyTracks;
      case 'feel good':
      case 'commute':
        return _romanceTracks;
      case 'sad':
        return _relaxTracks;
      default:
        return CreatorsChoiceService.getVerifiedTracks().take(12).toList();
    }
  }

  static List<MoodSection> getMoodSections(String category) {
    final cat = category.trim().toLowerCase();

    if (cat == 'sleep') {
      return [
        MoodCardSection(
          title: 'Deep focus',
          items: [
            MoodCardItem(
              title: 'Left Brain, Right Beat',
              subtitle: 'Floating Points, Floating Focus',
              imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Left brain right beat focus',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Classical Focus',
              subtitle: 'Johann Sebastian Bach, Mozart',
              imageUrl: 'https://images.unsplash.com/photo-1520523839898-507127027d53?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Classical focus piano',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Mellow Solo Piano',
              subtitle: 'Everfield, Star Acoustic',
              imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Mellow solo piano sleep',
              fallbackTracks: _sleepTracks,
            ),
            MoodCardItem(
              title: 'Deep Minimum',
              subtitle: 'Dosem, Ambient Calm',
              imageUrl: 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Deep minimum ambient focus',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Brown Noise',
              subtitle: 'SleepTherapy, 8 Hours Calm',
              imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Brown noise for sleep',
              fallbackTracks: _sleepTracks,
            ),
            MoodCardItem(
              title: 'White Noise',
              subtitle: 'White Noise Sound Masking',
              imageUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'White noise sleep',
              fallbackTracks: _sleepTracks,
            ),
          ],
        ),
        MoodCardSection(
          title: 'Musical sleep',
          items: [
            MoodCardItem(
              title: 'Midnight Romance: Hindi',
              subtitle: 'Arijit Singh, Mohit Chauhan',
              imageUrl: 'https://c.saavncdn.com/495/World-Music-Day-Hindi-2025-20260217171350-500x500.webp',
              searchQuery: 'Midnight Romance Hindi songs',
              fallbackTracks: _sleepTracks,
            ),
            MoodCardItem(
              title: 'Gentle Piano',
              subtitle: 'The Chillest, Peaceful Piano',
              imageUrl: 'https://images.unsplash.com/photo-1520523839898-507127027d53?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Gentle piano peaceful sleep',
              fallbackTracks: _sleepTracks,
            ),
            MoodCardItem(
              title: 'Happy Dreams: Hindi',
              subtitle: 'Arijit Singh, Amit Trivedi',
              imageUrl: 'https://c.saavncdn.com/504/Arz-Kiya-Hai-Coke-Studio-Bharat-Hindi-2025-20250818054005-500x500.webp',
              searchQuery: 'Happy dreams peaceful Hindi',
              fallbackTracks: _sleepTracks,
            ),
            MoodCardItem(
              title: 'Gentle Acoustic Instrumentals',
              subtitle: 'Acoustic Guitar, Ambient Strings',
              imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Gentle acoustic instrumentals sleep',
              fallbackTracks: _sleepTracks,
            ),
          ],
        ),
        MoodCardSection(
          title: 'Meditative sleep',
          items: [
            MoodCardItem(
              title: 'Rain & Thunder Calm',
              subtitle: 'Nature Meditation',
              imageUrl: 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Rain and thunder meditation',
              fallbackTracks: _sleepTracks,
            ),
            MoodCardItem(
              title: 'Tibetan Singing Bowls',
              subtitle: 'Healing Frequency 432Hz',
              imageUrl: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Tibetan singing bowls sleep meditation',
              fallbackTracks: _sleepTracks,
            ),
          ],
        ),
      ];
    }

    if (cat == 'focus') {
      return [
        MoodCardSection(
          tag: 'STAYING FOCUSED',
          title: 'Deep focus',
          items: [
            MoodCardItem(
              title: 'Left Brain, Right Beat',
              subtitle: 'Floating Points, Electronic Focus',
              imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Deep focus beats',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Classical Focus',
              subtitle: 'Johann Sebastian Bach, Vivaldi',
              imageUrl: 'https://images.unsplash.com/photo-1520523839898-507127027d53?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Classical focus music',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Jazz Focus',
              subtitle: 'John Coltrane, Miles Davis',
              imageUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Jazz study focus',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Brazilian Phonk (slowed)',
              subtitle: 'Chill Phonk, Slowed Tempo',
              imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Brazilian phonk slowed study',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Brown Noise',
              subtitle: 'Noise Therapy, Continuous',
              imageUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Brown noise study',
              fallbackTracks: _focusTracks,
            ),
          ],
        ),
        MoodCardSection(
          title: 'Ambient + atmospheric',
          items: [
            MoodCardItem(
              title: 'Lofi Loft',
              subtitle: 'Chill Beats to Study & Relax',
              imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Lofi loft beats',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Rain Sounds',
              subtitle: 'Gentle Rain on Window',
              imageUrl: 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Rain sounds ambient focus',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Lofi Flow State',
              subtitle: 'Continuous Productive Lo-Fi',
              imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Lofi flow state music',
              fallbackTracks: _focusTracks,
            ),
          ],
        ),
        MoodCardSection(
          title: 'Flow state',
          items: [
            MoodCardItem(
              title: 'Minimal Techno Flow',
              subtitle: 'Steady Rhythmic Electronics',
              imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Minimal techno flow focus',
              fallbackTracks: _focusTracks,
            ),
            MoodCardItem(
              title: 'Electronic Focus',
              subtitle: 'Floating Points, Ambient Synths',
              imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Electronic mind focus ambient',
              fallbackTracks: _focusTracks,
            ),
          ],
        ),
      ];
    }

    if (cat == 'relax') {
      return [
        MoodCardSection(
          tag: 'FOR RELAXING',
          title: 'Coffee shop blends',
          items: [
            MoodCardItem(
              title: 'Uncut Bollywood',
              subtitle: 'Arijit Singh, Pritam, Mohit',
              imageUrl: 'https://c.saavncdn.com/451/Airlift-Hindi-2015-500x500.jpg',
              searchQuery: 'Uncut Bollywood acoustic songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: '90s Chill: Bollywood',
              subtitle: 'Kumar Sanu, Alka Yagnik, Udit',
              imageUrl: 'https://c.saavncdn.com/223/Jab-We-Met-Hindi-2007-20231016162009-500x500.webp',
              searchQuery: '90s chill bollywood acoustic',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: 'All-Time Easy Acoustics',
              subtitle: 'The Beatles, Ed Sheeran, Anuv',
              imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Easy acoustic songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: 'Soulful Tollywood',
              subtitle: 'Sid Sriram, Anirudh',
              imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Soulful Tollywood songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: "Feelin' Good: Indian Indie",
              subtitle: 'Aditya A, Saahel, Anuv Jain',
              imageUrl: 'https://c.saavncdn.com/084/Indie-Campus-Chill-Hits-Hindi-2024-20240627120630-500x500.webp',
              searchQuery: 'Indian indie chill songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: 'Coffee Shop Indie',
              subtitle: 'Hozier, Novo Amor, Prateek Kuhad',
              imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Coffee shop indie acoustic',
              fallbackTracks: _relaxTracks,
            ),
          ],
        ),
        MoodSongGridSection(
          title: 'Song mixes',
          tracks: _relaxTracks,
        ),
      ];
    }

    if (cat == 'romance') {
      return [
        MoodCardSection(
          title: 'Sweethearts & romance',
          items: [
            MoodCardItem(
              title: 'Bollywood Romantic Moments',
              subtitle: 'Arijit Singh, Pritam, Shreya Ghoshal',
              imageUrl: 'https://c.saavncdn.com/971/Gold-Hindi-2018-20250617065303-500x500.webp',
              searchQuery: 'Bollywood romantic hits',
              fallbackTracks: _romanceTracks,
            ),
            MoodCardItem(
              title: 'Ultimate Love Songs',
              subtitle: 'Adele, Taylor Swift, Ed Sheeran',
              imageUrl: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Ultimate love songs romantic',
              fallbackTracks: _romanceTracks,
            ),
            MoodCardItem(
              title: 'Punjabi Romance',
              subtitle: 'Diljit Dosanjh, B Praak',
              imageUrl: 'https://c.saavncdn.com/121/Suniyan-Suniyan-Punjabi-2024-20240415211002-500x500.webp',
              searchQuery: 'Punjabi romantic songs',
              fallbackTracks: _romanceTracks,
            ),
            MoodCardItem(
              title: 'Bollywood Love Aaj Kal',
              subtitle: 'Arijit Singh, Amit Trivedi',
              imageUrl: 'https://c.saavncdn.com/944/Baaghi-Hindi-2016-20220420171003-500x500.webp',
              searchQuery: 'Bollywood modern love songs',
              fallbackTracks: _romanceTracks,
            ),
            MoodCardItem(
              title: 'The Look of 80s Love',
              subtitle: 'Kishore Kumar, Lata Mangeshkar',
              imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&auto=format&fit=crop&q=80',
              searchQuery: '80s bollywood romantic classics',
              fallbackTracks: _romanceTracks,
            ),
          ],
        ),
        MoodSongGridSection(
          title: 'Song mixes',
          tracks: _romanceTracks,
        ),
      ];
    }

    if (cat == 'party') {
      return [
        MoodCardSection(
          title: 'Indian party',
          items: [
            MoodCardItem(
              title: 'Bollywood Fire',
              subtitle: 'Badshah, Yo Yo Honey Singh, Neha',
              imageUrl: 'https://c.saavncdn.com/638/Arijit-Singh-X-Badshah-The-Biggest-Songs-2024-Hindi-2024-20240410215733-500x500.webp',
              searchQuery: 'Bollywood dance party hits',
              fallbackTracks: _partyTracks,
            ),
            MoodCardItem(
              title: 'Punjabi Party Bangers',
              subtitle: 'Karan Aujla, Diljit Dosanjh',
              imageUrl: 'https://c.saavncdn.com/121/Suniyan-Suniyan-Punjabi-2024-20240415211002-500x500.webp',
              searchQuery: 'Punjabi party songs high energy',
              fallbackTracks: _partyTracks,
            ),
            MoodCardItem(
              title: 'Bollywood EDM',
              subtitle: 'Nucleya, Lost Stories',
              imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Bollywood EDM dance party',
              fallbackTracks: _partyTracks,
            ),
            MoodCardItem(
              title: 'Tollywood Dance Essentials',
              subtitle: 'Anirudh, Thaman S',
              imageUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Tollywood party dance hits',
              fallbackTracks: _partyTracks,
            ),
          ],
        ),
        MoodSongGridSection(
          title: 'Song mixes',
          tracks: _partyTracks,
        ),
      ];
    }

    if (cat == 'energize') {
      return [
        MoodSongGridSection(
          title: 'Quick picks',
          tracks: _partyTracks,
        ),
        MoodCardSection(
          title: 'Pop bangers',
          items: [
            MoodCardItem(
              title: 'Bollywood Recharger',
              subtitle: 'High tempo dance anthems',
              imageUrl: 'https://c.saavncdn.com/638/Arijit-Singh-X-Badshah-The-Biggest-Songs-2024-Hindi-2024-20240410215733-500x500.webp',
              searchQuery: 'Bollywood high energy workout songs',
              fallbackTracks: _partyTracks,
            ),
            MoodCardItem(
              title: 'Upbeat Bollywood',
              subtitle: 'Badshah, Tanishk Bagchi',
              imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Upbeat Bollywood dance tracks',
              fallbackTracks: _partyTracks,
            ),
            MoodCardItem(
              title: 'Cardio Pop',
              subtitle: 'Dua Lipa, Calvin Harris',
              imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Cardio workout pop music',
              fallbackTracks: _partyTracks,
            ),
          ],
        ),
      ];
    }

    if (cat == 'podcasts') {
      return [
        MoodSongGridSection(
          title: 'Books',
          tracks: _podcastBooksTracks,
        ),
        MoodSongGridSection(
          title: 'Fiction',
          tracks: _podcastFictionTracks,
        ),
        MoodCardSection(
          title: 'Education & Insights',
          items: [
            MoodCardItem(
              title: 'The Ranveer Show (TRS)',
              subtitle: 'Ranveer Allahbadia',
              imageUrl: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'The Ranveer show podcast Hindi',
              fallbackTracks: _podcastBooksTracks,
            ),
            MoodCardItem(
              title: 'Finshots Daily',
              subtitle: 'Financial insights in 5 mins',
              imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Finshots daily podcast',
              fallbackTracks: _podcastBooksTracks,
            ),
          ],
        ),
      ];
    }

    if (cat == 'sad') {
      return [
        MoodCardSection(
          title: 'Breakups & heartbreak',
          items: [
            MoodCardItem(
              title: 'Bollywood Heartbreak',
              subtitle: 'Arijit Singh, Pritam',
              imageUrl: 'https://c.saavncdn.com/750/Ek-Tarfa-Hindi-2020-20260226174102-500x500.webp',
              searchQuery: 'Bollywood sad heartbreak songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: 'Sad Anthems: Punjabi',
              subtitle: 'B Praak, Jaani',
              imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Sad punjabi emotional songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: '#sadforever',
              subtitle: 'Adele, Coldplay',
              imageUrl: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=500&auto=format&fit=crop&q=80',
              searchQuery: 'Emotional sad acoustic songs',
              fallbackTracks: _relaxTracks,
            ),
          ],
        ),
        MoodCardSection(
          title: 'Bollywood sad',
          items: [
            MoodCardItem(
              title: '90s Bollywood Sad Songs',
              subtitle: 'Kumar Sanu, Udit Narayan',
              imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&auto=format&fit=crop&q=80',
              searchQuery: '90s bollywood sad songs',
              fallbackTracks: _relaxTracks,
            ),
            MoodCardItem(
              title: 'Bollywood Melancholy',
              subtitle: 'Mohit Chauhan, KK',
              imageUrl: 'https://c.saavncdn.com/128/Behen-Hogi-Teri-Hindi-2017-500x500.jpg',
              searchQuery: 'Bollywood melancholy emotional',
              fallbackTracks: _relaxTracks,
            ),
          ],
        ),
      ];
    }

    // Default for Workout, Feel good, Commute
    return [
      MoodCardSection(
        tag: 'FOR FEELING GOOD',
        title: '$category & Mood specials',
        items: [
          MoodCardItem(
            title: 'Top $category Anthems',
            subtitle: 'Curated verified selections',
            imageUrl: 'https://c.saavncdn.com/971/Gold-Hindi-2018-20250617065303-500x500.webp',
            searchQuery: '$category songs',
            fallbackTracks: _romanceTracks,
          ),
          MoodCardItem(
            title: 'Classic Mixes',
            subtitle: 'Best of Bollywood & Indie',
            imageUrl: 'https://c.saavncdn.com/451/Airlift-Hindi-2015-500x500.jpg',
            searchQuery: 'Best bollywood melodies',
            fallbackTracks: _relaxTracks,
          ),
        ],
      ),
      MoodSongGridSection(
        title: 'Song mixes',
        tracks: _romanceTracks,
      ),
    ];
  }
}
