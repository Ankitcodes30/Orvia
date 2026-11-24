import 'package:Orvia/core/models/exported.dart';

class CategoryTracksService {
  static List<Track> getTracksForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'podcasts':
        return _podcastTracks;
      case 'romance':
        return _romanceTracks;
      case 'feel good':
        return _feelGoodTracks;
      case 'workout':
        return _workoutTracks;
      case 'relax':
        return _relaxTracks;
      case 'energize':
        return _energizeTracks;
      case 'party':
        return _partyTracks;
      case 'focus':
        return _focusTracks;
      default:
        return const [];
    }
  }

  static Track _t({
    required String id,
    required String title,
    required String artist,
    required String thumb,
    int duration = 240,
  }) {
    final artwork = Artwork(
      url: thumb,
      urlLow: thumb,
      urlHigh: thumb,
      layout: ImageLayout.square,
    );
    return Track(
      id: 'content-resolver.bloomfactory.ytvideo::$id',
      title: title,
      artists: [
        ArtistSummary(
          id: '',
          name: artist,
          thumbnail: artwork,
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: title,
        artists: const [],
        thumbnail: artwork,
      ),
      durationMs: BigInt.from(duration * 1000),
      thumbnail: artwork,
      isExplicit: false,
    );
  }

  static final List<Track> _podcastTracks = [
    _t(
      id: 'pod_01',
      title: 'The Ranveer Show (TRS Hindi)',
      artist: 'Ranveer Allahbadia',
      thumb: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_02',
      title: 'Finshots Daily - Finance Insights',
      artist: 'Finshots',
      thumb: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_03',
      title: 'Desi Crime Podcast',
      artist: 'Desi Studios',
      thumb: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_04',
      title: 'Maha Bharat with Dhruv Rathee',
      artist: 'Dhruv Rathee',
      thumb: 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_05',
      title: 'Paisa Vaisa with Anupam Gupta',
      artist: 'Anupam Gupta',
      thumb: 'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_06',
      title: 'Cyrus Says Podcast',
      artist: 'Cyrus Broacha',
      thumb: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_07',
      title: 'Indian Noir Crime & Horror',
      artist: 'Nikesh Murali',
      thumb: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pod_08',
      title: 'The Seen and the Unseen',
      artist: 'Amit Varma',
      thumb: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _romanceTracks = [
    _t(
      id: 'rom_01',
      title: 'Kesariya',
      artist: 'Arijit Singh, Pritam',
      thumb: 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_02',
      title: 'Tum Hi Ho',
      artist: 'Arijit Singh, Mithoon',
      thumb: 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_03',
      title: 'Raataan Lambiyan',
      artist: 'Jubin Nautiyal, Asees Kaur',
      thumb: 'https://images.unsplash.com/photo-1529333166437-7750a6dd5a70?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_04',
      title: 'Pehle Bhi Main',
      artist: 'Vishal Mishra, Raj Shekhar',
      thumb: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_05',
      title: 'Apna Bana Le',
      artist: 'Arijit Singh, Sachin-Jigar',
      thumb: 'https://images.unsplash.com/photo-1474552226712-ac0f0961a954?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_06',
      title: 'Dil Diyan Gallan',
      artist: 'Atif Aslam, Vishal-Shekhar',
      thumb: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_07',
      title: 'O Maahi (Dunki)',
      artist: 'Arijit Singh, Pritam',
      thumb: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rom_08',
      title: 'Tere Hawaale',
      artist: 'Arijit Singh, Shilpa Rao',
      thumb: 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _feelGoodTracks = [
    _t(
      id: 'fg_01',
      title: 'Ilahi',
      artist: 'Arijit Singh, Pritam',
      thumb: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_02',
      title: 'Matargashti',
      artist: 'Mohit Chauhan, A.R. Rahman',
      thumb: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_03',
      title: 'Love You Zindagi',
      artist: 'Jasleen Royal, Amit Trivedi',
      thumb: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_04',
      title: 'Safarnama',
      artist: 'Lucky Ali, A.R. Rahman',
      thumb: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_05',
      title: 'Phir Se Ud Chala',
      artist: 'Mohit Chauhan, A.R. Rahman',
      thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_06',
      title: 'Hawayein',
      artist: 'Arijit Singh, Pritam',
      thumb: 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_07',
      title: 'Subhanallah',
      artist: 'Sreerama Chandra, Shilpa Rao',
      thumb: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'fg_08',
      title: 'Badtameez Dil',
      artist: 'Benny Dayal, Pritam',
      thumb: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _workoutTracks = [
    _t(
      id: 'wo_01',
      title: 'Zinda (Bhaag Milkha Bhaag)',
      artist: 'Siddharth Mahadevan, Shankar-Ehsaan-Loy',
      thumb: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_02',
      title: 'Kar Har Maidaan Fateh',
      artist: 'Sukhwinder Singh, Shreya Ghoshal',
      thumb: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_03',
      title: 'Brothers Anthem',
      artist: 'Vishal Dadlani, Ajay-Atul',
      thumb: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_04',
      title: 'Sultan Title Track',
      artist: 'Sukhwinder Singh, Vishal-Shekhar',
      thumb: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_05',
      title: 'Dangal Title Track',
      artist: 'Daler Mehndi, Pritam',
      thumb: 'https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_06',
      title: 'Chak De India',
      artist: 'Sukhwinder Singh, Salim-Sulaiman',
      thumb: 'https://images.unsplash.com/photo-1549060279-7e168fcee0c2?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_07',
      title: 'Believer',
      artist: 'Imagine Dragons',
      thumb: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'wo_08',
      title: 'Hall of Fame',
      artist: 'The Script, will.i.am',
      thumb: 'https://images.unsplash.com/photo-1434493789847-2f02dc6ca35d?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _relaxTracks = [
    _t(
      id: 'rel_01',
      title: 'Iktara (Wake Up Sid)',
      artist: 'Amit Trivedi, Kavita Seth',
      thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_02',
      title: 'Kun Faya Kun',
      artist: 'A.R. Rahman, Mohit Chauhan, Javed Ali',
      thumb: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_03',
      title: 'Sham (Aisha)',
      artist: 'Amit Trivedi, Nikhil D\'Souza',
      thumb: 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_04',
      title: 'Kho Gaye Hum Kahan',
      artist: 'Jasleen Royal, Prateek Kuhad',
      thumb: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_05',
      title: 'Kasoor (Acoustic)',
      artist: 'Prateek Kuhad',
      thumb: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_06',
      title: 'Baarishein',
      artist: 'Anuv Jain',
      thumb: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_07',
      title: 'Alag Aasmaan',
      artist: 'Anuv Jain',
      thumb: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'rel_08',
      title: 'Arziyan (Delhi-6)',
      artist: 'Javed Ali, Kailash Kher, A.R. Rahman',
      thumb: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _energizeTracks = [
    _t(
      id: 'eng_01',
      title: 'Ghungroo',
      artist: 'Arijit Singh, Shilpa Rao, Vishal-Shekhar',
      thumb: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_02',
      title: 'Gallan Goodiyaan',
      artist: 'Yashita Sharma, Sukhwinder Singh',
      thumb: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_03',
      title: 'London Thumakda',
      artist: 'Labh Janjua, Sonu Kakkar, Neha Kakkar',
      thumb: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_04',
      title: 'Kala Chashma',
      artist: 'Amar Arshi, Badshah, Neha Kakkar',
      thumb: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_05',
      title: 'Aankh Marey',
      artist: 'Neha Kakkar, Mika Singh, Tanishk Bagchi',
      thumb: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_06',
      title: 'Kar Gayi Chull',
      artist: 'Badshah, Fazilpuria, Sukriti Kakar',
      thumb: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_07',
      title: 'Nashe Si Chadh Gayi',
      artist: 'Arijit Singh, Vishal-Shekhar',
      thumb: 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'eng_08',
      title: 'The Humma Song',
      artist: 'Jubin Nautiyal, Shashaa Tirupati, Badshah',
      thumb: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _partyTracks = [
    _t(
      id: 'pty_01',
      title: 'Abhi Toh Party Shuru Hui Hai',
      artist: 'Badshah, Aastha Gill',
      thumb: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_02',
      title: 'Hookah Bar',
      artist: 'Himesh Reshammiya, Vineet Singh',
      thumb: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_03',
      title: 'Subah Hone Na De',
      artist: 'Mika Singh, Shefali Alvares',
      thumb: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_04',
      title: 'Dilliwaali Girlfriend',
      artist: 'Arijit Singh, Sunidhi Chauhan, Pritam',
      thumb: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_05',
      title: 'Chitta Ve',
      artist: 'Shahid Mallya, Amit Trivedi',
      thumb: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_06',
      title: 'Makhna',
      artist: 'Tanishk Bagchi, Yasser Desai, Asees Kaur',
      thumb: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_07',
      title: 'Saturday Saturday',
      artist: 'Badshah, Indeep Bakshi, Akriti Kakar',
      thumb: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'pty_08',
      title: 'Proper Patola',
      artist: 'Diljit Dosanjh, Badshah, Aastha Gill',
      thumb: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
    ),
  ];

  static final List<Track> _focusTracks = [
    _t(
      id: 'foc_01',
      title: 'Interstellar Main Theme (Piano)',
      artist: 'Hans Zimmer',
      thumb: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_02',
      title: 'Lofi Rain Beats',
      artist: 'A.K. Music World',
      thumb: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_03',
      title: 'Peaceful Flute & Tanpura',
      artist: 'Pandit Hariprasad Chaurasia',
      thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_04',
      title: 'Ambient Sitar Journey',
      artist: 'Pandit Ravi Shankar',
      thumb: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_05',
      title: 'Midnight Piano Harmony',
      artist: 'A.K. Music World',
      thumb: 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_06',
      title: 'Deep Focus Alpha Wave',
      artist: 'Brainwave Symphony',
      thumb: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_07',
      title: 'Himalayan Stream Meditative Flute',
      artist: 'Naveen Kumar',
      thumb: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=500&auto=format&fit=crop&q=80',
    ),
    _t(
      id: 'foc_08',
      title: 'Indian Classical Santoor Harmony',
      artist: 'Pandit Shivkumar Sharma',
      thumb: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
    ),
  ];
}
