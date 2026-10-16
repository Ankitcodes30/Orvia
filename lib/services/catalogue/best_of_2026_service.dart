import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';

/// Service providing verified 2026 releases for Indian music discovery.
class BestOf2026Service {
  static const String pluginId = kDefaultSaavnPluginId;

  static List<Track> getVerified2026Tracks() {
    return _kVerified2026Tracks;
  }

  static Track _track({
    required String rawId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    final compositeId = '$pluginId::$rawId';
    return Track(
      id: compositeId,
      title: title,
      artists: [
        ArtistSummary(
          id: '',
          name: artist,
          thumbnail: Artwork(url: imageUrl, urlLow: imageUrl, urlHigh: imageUrl, layout: ImageLayout.square),
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: Artwork(url: imageUrl, urlLow: imageUrl, urlHigh: imageUrl, layout: ImageLayout.square),
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(url: imageUrl, urlLow: imageUrl, urlHigh: imageUrl, layout: ImageLayout.square),
      isExplicit: false,
    );
  }

  static final List<Track> _kVerified2026Tracks = [
    _track(rawId: 'lrS3vdPs', title: 'Banger', artist: 'Badshah, Hiten, Sharvi Yadav', album: 'Banger', durationSec: 158, imageUrl: 'https://c.saavncdn.com/984/Banger-Hindi-2026-20260808053559-500x500.webp'),
    _track(rawId: '47_T2N3p', title: 'Casa Tupka Anthemo', artist: 'Yo Yo Honey Singh', album: 'Casa Tupka Anthemo', durationSec: 183, imageUrl: 'https://c.saavncdn.com/786/Casa-Tupka-Anthemo-Hindi-2026-20260917173352-500x500.webp'),
    _track(rawId: 'x8gA2kXk', title: 'Boom Shaka', artist: 'Dhanda Nyoliwala, KR\$NA', album: 'Boom Shaka', durationSec: 218, imageUrl: 'https://c.saavncdn.com/307/Boom-Shaka-Hindi-2026-20260428064906-500x500.webp'),
    _track(rawId: '0IYB3TD8', title: 'Parda Naa Kar Pujari Dikhne De Radha Pyaari', artist: 'Karan Thakur, Kratika Thakur', album: 'Parda Naa Kar Pujari Dikhne De Radha Pyaari', durationSec: 186, imageUrl: 'https://c.saavncdn.com/828/Parda-Naa-Kar-Pujari-Dikhne-De-Radha-Pyaari-Hindi-2026-20260618200001-500x500.webp'),
    _track(rawId: '3f80KEPr', title: 'Legacy Anthem', artist: 'KR\$NA, Raftaar, DRJ Sohail', album: 'Legacy Anthem', durationSec: 122, imageUrl: 'https://c.saavncdn.com/508/Legacy-Anthem-Hindi-2026-20260709074611-500x500.webp'),
    _track(rawId: 'sWgsgYrT', title: 'He Yashodasut Nand Ke Nandan-Krishna Vandana', artist: 'Amrita Chaturvedi, Upadhyay', album: 'He Yashodasut Nand Ke Nandan-Krishna Vandana', durationSec: 135, imageUrl: 'https://c.saavncdn.com/383/He-Yashodasut-Nand-Ke-Nandan-Krishna-Vandana-Hindi-2026-20260112155403-500x500.webp'),
    _track(rawId: 'B425R8VU', title: 'Parda Na Kar Pujari Dikhne De Radha Pyari', artist: 'Hansraj Railhan', album: 'Parda Na Kar Pujari Dikhne De Radha Pyari', durationSec: 271, imageUrl: 'https://c.saavncdn.com/027/Parda-Na-Kar-Pujari-Dikhne-De-Radha-Pyari-Hindi-2026-20260627123605-500x500.webp'),
    _track(rawId: 'bwxIH15P', title: 'Dil Na Diya (Krrish Ka Gana Sunega)', artist: 'Ankush Raja, Rajnandini Singh, Rajesh Roshan, Vicky Vox, Vijay Akela, Prakash Barud', album: 'Dil Na Diya (Krrish Ka Gana Sunega)', durationSec: 248, imageUrl: 'https://c.saavncdn.com/542/Dil-Na-Diya-Krrish-Ka-Gana-Sunega-Unknown-2026-20260106171014-500x500.webp'),
    _track(rawId: 'QPMdo814', title: 'Krishna Unka Naam Hai', artist: 'Kaushal Kishore, Indresh Upadhyay, Surabhi Tiwari', album: 'Krishna Unka Naam Hai', durationSec: 299, imageUrl: 'https://c.saavncdn.com/519/Krishna-Unka-Naam-Hai-Hindi-2026-20260428193208-500x500.webp'),
    _track(rawId: 'JTx45m6s', title: 'Om Krishnay Vasudevay Hare Parmatmane Pranatakleshanashay Govindaya Namo Namah', artist: 'Vijay Chindhote, Yogita Chindhote', album: 'Om Krishnay Vasudevay Hare Parmatmane Pranatakleshanashay Govindaya Namo Namah', durationSec: 479, imageUrl: 'https://c.saavncdn.com/487/Om-Krishnay-Vasudevay-Hare-Parmatmane-Pranatakleshanashay-Govindaya-Namo-Namah-Hindi-2026-20260128075220-500x500.webp'),
    _track(rawId: 'dfxMUgNt', title: 'Prozpekt to KR\$NA', artist: 'RythmCode', album: 'Prozpekt to KR\$NA', durationSec: 209, imageUrl: 'https://c.saavncdn.com/721/Prozpekt-to-KR-NA-Hindi-2026-20260831070658-500x500.webp'),
    _track(rawId: 'fB-j5y6j', title: 'Ishq Na Kr', artist: 'Gulfam Ahtisham Sanjrani', album: 'Ishq Na Kr', durationSec: 365, imageUrl: 'https://c.saavncdn.com/530/Ishq-Na-Kr-Punjabi-2026-20260630160613-500x500.webp'),
    _track(rawId: 'XI6GCrXx', title: 'Dusk', artist: 'Mukul Verma, Bhoomi, Sparsh Dangwal', album: 'Dusk', durationSec: 164, imageUrl: 'https://c.saavncdn.com/758/Dusk-Hindi-2026-20260702163223-500x500.webp'),
    _track(rawId: 'mbjgrUSr', title: 'LOVE COLLAB MASHUP', artist: 'Abeer Chopra, Kushagra, DJ Sumit Rajwanshi, Tanishka Bahl, Bhoomi', album: 'LOVE COLLAB MASHUP', durationSec: 342, imageUrl: 'https://c.saavncdn.com/113/LOVE-COLLAB-MASHUP-Hindi-2026-20260416201618-500x500.webp'),
    _track(rawId: '71i5YEN7', title: 'Keh Do Na', artist: 'Nihal Ahmed, PLUSHY, Drew.', album: 'Keh Do Na', durationSec: 149, imageUrl: 'https://c.saavncdn.com/957/Keh-Do-Na-Hindi-2026-20260722131829-500x500.webp'),
    _track(rawId: 'nnaTX0Sj', title: 'Jhinka Chika Jhinka Chika Jhikanka (Slowed)', artist: 'Ishika Joshi', album: 'Pagol Mon', durationSec: 317, imageUrl: 'https://c.saavncdn.com/425/Pagol-Mon-Hindi-2026-20260326194344-500x500.webp'),
    _track(rawId: 'wB11DmaH', title: 'Vaada', artist: 'Bhoomi', album: 'Vaada', durationSec: 156, imageUrl: 'https://c.saavncdn.com/374/Vaada-Malayalam-2026-20260603230551-500x500.webp'),
    _track(rawId: 'pliyoMG2', title: 'Mon Amar Pagal Hoye Poddo Patay Bose (Sped Up)', artist: 'Ishika Joshi', album: 'Mon Amar', durationSec: 202, imageUrl: 'https://c.saavncdn.com/753/Mon-Amar-Hindi-2026-20260326205533-500x500.webp'),
    _track(rawId: 'mOTftlgj', title: 'Tumake Bor Bhal Pau', artist: 'Apom Anupam', album: 'Tumake Bor Bhal Pau', durationSec: 191, imageUrl: 'https://c.saavncdn.com/830/Tumake-Bor-Bhal-Pau-Assamese-2026-20260420162801-500x500.webp'),
    _track(rawId: 'qckqHCqc', title: '2 Bhai', artist: 'Ajay Sharaya, Gulshan Baba', album: '2 Bhai', durationSec: 146, imageUrl: 'https://c.saavncdn.com/479/2-Bhai-Haryanvi-2026-20260512105813-500x500.webp'),
    _track(rawId: 'Be1lK0aM', title: 'Kithe Jawan (Remix)', artist: 'Bhoomi', album: 'Kithe Jawan (Remix)', durationSec: 196, imageUrl: 'https://c.saavncdn.com/622/Kithe-Jawan-Remix-Hindi-2026-20260606163642-500x500.webp'),
    _track(rawId: 'v26UgpNb', title: 'Haasil (Lofi Version)', artist: 'Bhoomi', album: 'Haasil (Lofi Version)', durationSec: 142, imageUrl: 'https://c.saavncdn.com/179/Haasil-Lofi-Version-Hindi-2026-20260707224842-500x500.webp'),
    _track(rawId: 'HpeaRN-V', title: 'Jogan (Lofi Version)', artist: 'Shantanu Karki, MANIKK, Bhoomi, Naaz', album: 'Jogan (Lofi Version)', durationSec: 201, imageUrl: 'https://c.saavncdn.com/466/Jogan-Lofi-Version-Punjabi-2026-20260622204403-500x500.webp'),
    _track(rawId: 'vcXsHs5M', title: 'With You (Lofi)', artist: 'Bhoomi, Naaz, GURDIT', album: 'With You (Lofi)', durationSec: 145, imageUrl: 'https://c.saavncdn.com/665/With-You-Lofi-Hindi-2026-20260720224012-500x500.webp'),
    _track(rawId: 'dxrBpjVX', title: 'Sabar (From "Bhoomi 2026")', artist: 'Salim-Sulaiman, Armaan Malik, Shraddha Pandit', album: 'Sabar (From "Bhoomi 2026")', durationSec: 277, imageUrl: 'https://c.saavncdn.com/810/Sabar-From-Bhoomi-2026-Hindi-2026-20261004205229-500x500.webp'),
    _track(rawId: 'nrv1l2H9', title: 'Paagal (From "Bhoomi 2026")', artist: 'Salim-Sulaiman, Sonu Nigam, Shraddha Pandit', album: 'Paagal (From "Bhoomi 2026")', durationSec: 183, imageUrl: 'https://c.saavncdn.com/444/Paagal-From-Bhoomi-2026-Hindi-2026-20260926170307-500x500.webp'),
    _track(rawId: 'mCe5xMpw', title: 'Nuksaan (from "Bhoomi 2026")', artist: 'Salim-Sulaiman, Afsana Khan, Saida Begum, Happy Raikoti', album: 'Nuksaan (from "Bhoomi 2026")', durationSec: 245, imageUrl: 'https://c.saavncdn.com/300/Nuksaan-from-Bhoomi-2026-Punjabi-2026-20260821161838-500x500.webp'),
    _track(rawId: 'TXW2bY_V', title: 'Kaanuda (from "Bhoomi 2026")', artist: 'Salim-Sulaiman, Aditya Gadhvi', album: 'Kaanuda (from "Bhoomi 2026")', durationSec: 322, imageUrl: 'https://c.saavncdn.com/379/Kaanuda-from-Bhoomi-2026-Gujarati-2026-20260827130547-500x500.webp'),
    _track(rawId: 'Y6hNA-jc', title: 'Sukoon 2.0', artist: 'Shraddha Pandit, Salim-Sulaiman, Arijit Singh, Anshuman Sharma', album: 'Sukoon 2.0', durationSec: 350, imageUrl: 'https://c.saavncdn.com/204/Sukoon-2-0-Hindi-2026-20260109114228-500x500.webp'),
    _track(rawId: 'N3dqaVyM', title: 'Sukoon (From "Bhoomi 2025")', artist: 'Shraddha Pandit, Salim-Sulaiman, Arijit Singh', album: 'Sukoon 2.0', durationSec: 323, imageUrl: 'https://c.saavncdn.com/204/Sukoon-2-0-Hindi-2026-20260109114228-500x500.webp'),
    _track(rawId: 'GihMtU7z', title: 'Na Ja Re', artist: 'Shraddha Pandit, Salim-Sulaiman, Sonu Nigam, Anshuman Sharma', album: 'Na Ja Re', durationSec: 243, imageUrl: 'https://c.saavncdn.com/473/Na-Ja-Re-Hindi-2026-20260217133208-500x500.webp'),
    _track(rawId: '6Rnhv0dO', title: 'Haayi', artist: 'Anirudh Shandilya Maramraju, Salim Sulaiman, Sid Sriram', album: 'Haayi', durationSec: 324, imageUrl: 'https://c.saavncdn.com/578/Haayi-Telugu-2026-20260112114053-500x500.webp'),
    _track(rawId: 'o0gplyl2', title: 'Aafreen 2.0', artist: 'Amitabh Bhattacharya, Taylor Jones, Salim-Sulaiman, Salim Merchant', album: 'Aafreen 2.0', durationSec: 213, imageUrl: 'https://c.saavncdn.com/750/Aafreen-2-0-Hindi-2026-20260326122416-500x500.webp'),
    _track(rawId: 'NGU5heDX', title: 'Jironi', artist: 'Salim-Sulaiman, Dikshu, Rahul Gautam Sharma', album: 'Jironi', durationSec: 323, imageUrl: 'https://c.saavncdn.com/787/Jironi-Assamese-2026-20260814132149-500x500.webp'),
    _track(rawId: '-rR-vL3P', title: 'Into You', artist: 'Salim-Sulaiman, Arijit Singh, Ananya Sharma', album: 'Into You', durationSec: 167, imageUrl: 'https://c.saavncdn.com/997/Into-You-Hindi-2026-20260124113741-500x500.webp'),
    _track(rawId: 'lPwTTWKf', title: 'Karuvizhi (From "Haiku") (Tamil)', artist: 'Siddhu Kumar, Armaan Malik, Mohan Rajan', album: 'Karuvizhi (From "Haiku") (Tamil)', durationSec: 208, imageUrl: 'https://c.saavncdn.com/481/Karuvizhi-From-Haiku-Tamil-Tamil-2026-20261009084005-500x500.webp'),
    _track(rawId: 'o5ZbYv_v', title: 'Evare Nuvve (From "I\'M Game - Telugu")', artist: 'Jakes Bejoy, Armaan Malik, Sanare', album: 'Evare Nuvve (From "I\'M Game - Telugu")', durationSec: 264, imageUrl: 'https://c.saavncdn.com/854/Evare-Nuvve-From-I-M-Game-Telugu-Telugu-2026-20260810103433-500x500.jpg'),
    _track(rawId: 'AhwC2Od2', title: 'Kaho Toh (From "Prem Keetanu")', artist: 'Armaan Malik, Altamash Faridi, Annkur R Pathakk, Sachin Urmtosh', album: 'Kaho Toh (From "Prem Keetanu")', durationSec: 248, imageUrl: 'https://c.saavncdn.com/246/Kaho-Toh-From-Prem-Keetanu-Hindi-2026-20260828152834-500x500.webp'),
    _track(rawId: '8nduAxzy', title: 'Ram Ji Aake Bhala Karenge', artist: 'Kumaar, Mellow D, Pritam, Armaan Malik, Aarvan', album: 'New Music Hindi 2026', durationSec: 235, imageUrl: 'https://c.saavncdn.com/337/New-Music-Hindi-2026-Hindi-2026-20260518161134-500x500.webp'),
    _track(rawId: 'HjlW6wyL', title: 'Aakhri Ishq (From "Dhurandhar The Revenge")', artist: 'Irshad Kamil, Shashwat Sachdev, Jubin Nautiyal', album: 'Aakhri Ishq (From "Dhurandhar The Revenge")', durationSec: 262, imageUrl: 'https://c.saavncdn.com/635/Aakhri-Ishq-From-Dhurandhar-The-Revenge-Hindi-2026-20260324162413-500x500.webp'),
    _track(rawId: 'WqIWQXPT', title: 'Samjho Na', artist: 'Tanishk Bagchi, Jubin Nautiyal, Suvarna Tiwari, Manoj Muntashir', album: 'The Vvaan (Original Motion Picture Soundtrack)', durationSec: 253, imageUrl: 'https://c.saavncdn.com/554/The-Vvaan-Original-Motion-Picture-Soundtrack-Hindi-2026-20261001182647-500x500.webp'),
    _track(rawId: 'gDyBOkjj', title: 'Preet Re', artist: 'Darshan Raval, Rochak Kohli, Jonita Gandhi, Gurpreet Saini', album: 'Love Mode ON', durationSec: 196, imageUrl: 'https://c.saavncdn.com/768/Love-Mode-ON-Hindi-2026-20260824122556-500x500.webp'),
    _track(rawId: 'w48_f3Jj', title: 'Barsaat Lagdi Ae', artist: 'Darshan Raval, Simran Choudhary, Youngveer', album: 'Barsaat Lagdi Ae', durationSec: 186, imageUrl: 'https://c.saavncdn.com/418/Barsaat-Lagdi-Ae-Hindi-2026-20260729022553-500x500.webp'),
    _track(rawId: 'B6d7Dnf9', title: 'KALYANI (Remix)', artist: 'ARJN, KDS, FIFTY4, Shreya Ghoshal', album: 'KALYANI (Remix)', durationSec: 269, imageUrl: 'https://c.saavncdn.com/475/KALYANI-Remix-Malayalam-2026-20260622131127-500x500.webp'),
    _track(rawId: 'PTNX7k-6', title: 'Vaaroon Forever (From “Mirzapur The Movie”)', artist: 'Anand Bhaskar, Romy, Shreya Ghoshal, Ginny Diwan', album: 'Vaaroon Forever (From “Mirzapur The Movie”)', durationSec: 252, imageUrl: 'https://c.saavncdn.com/381/Vaaroon-Forever-From-Mirzapur-The-Movie-Hindi-2026-20260817160523-500x500.webp'),
    _track(rawId: 'LjTiw9yx', title: 'Zihaal e Miskin', artist: 'Javed-Mohsin, Vishal Mishra, Shreya Ghoshal', album: 'Best Monsoon Songs - 2026', durationSec: 244, imageUrl: 'https://c.saavncdn.com/222/Best-Monsoon-Songs-2026-Hindi-2026-20260723053833-500x500.webp'),
    _track(rawId: 'HIIQCV1i', title: 'Tujh Mein Basi Meri Jaan (From "Prahaar: The Untold Story Of Ujjwal Nikam")', artist: 'Pritam, Sonu Nigam, Shreya Ghoshal, Amitabh Bhattacharya', album: 'Tujh Mein Basi Meri Jaan (From "Prahaar: The Untold Story Of Ujjwal Nikam")', durationSec: 234, imageUrl: 'https://c.saavncdn.com/202/Tujh-Mein-Basi-Meri-Jaan-From-Prahaar-The-Untold-Story-Of-Ujjwal-Nikam-Hindi-2026-20261008171013-500x500.jpg'),
    _track(rawId: 'RbAbUbTm', title: 'Jai Ambe Bol From "Yeh Prem Mol Liya" (Reprise Extended)', artist: 'Himesh Reshammiya, Shreya Ghoshal, Parthiv Gohil, Mayur Puri', album: 'Jai Ambe Bol From "Yeh Prem Mol Liya" (Reprise Extended)', durationSec: 396, imageUrl: 'https://c.saavncdn.com/173/Jai-Ambe-Bol-From-Yeh-Prem-Mol-Liya-Reprise-Extended-Hindi-2026-20261011053200-500x500.webp'),
    _track(rawId: 'AIg8dSYa', title: 'Bairi Piya', artist: 'Shreya Ghoshal, Anurag Mishra, Alok Ranjan Srivastava', album: 'Bairi Piya', durationSec: 236, imageUrl: 'https://c.saavncdn.com/476/Bairi-Piya-Hindi-2026-20260923054031-500x500.webp'),
    _track(rawId: 'lDbCuERl', title: 'Jai Jai Ram (From "Ramayana")', artist: 'A.R. Rahman, Shreya Ghoshal, Arijit Singh, Kumar Vishwas', album: 'Jai Jai Ram (From "Ramayana")', durationSec: 320, imageUrl: 'https://c.saavncdn.com/816/Jai-Jai-Ram-From-Ramayana-Hindi-2026-20260914170135-500x500.webp'),
  ];
}
