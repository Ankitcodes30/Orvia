class RomanizerUtil {
  static const Map<String, String> _vowels = {
    'अ': 'a',
    'आ': 'aa',
    'इ': 'i',
    'ई': 'ee',
    'उ': 'u',
    'ऊ': 'oo',
    'ऋ': 'ri',
    'ए': 'e',
    'ऐ': 'ai',
    'ओ': 'o',
    'औ': 'au',
    'अं': 'an',
    'अः': 'ah',
  };

  static const Map<String, String> _matras = {
    'ा': 'a',
    'ि': 'i',
    'ी': 'ee',
    'ु': 'u',
    'ू': 'oo',
    'ृ': 'ri',
    'े': 'e',
    'ै': 'ai',
    'ो': 'o',
    'ौ': 'au',
    'ं': 'n',
    'ँ': 'n',
    'ः': 'h',
    '्': '',
  };

  static const Map<String, String> _consonants = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
    'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
    'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
    'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h',
    'क्ष': 'ksh', 'त्र': 'tr', 'ज्ञ': 'gy',
    'क़': 'q', 'ख़': 'kh', 'ग़': 'gh', 'ज़': 'z', 'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f',
  };

  static bool containsDevanagari(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0900 && code <= 0x097F) return true;
    }
    return false;
  }

  /// Transliterates Devanagari Hindi text to Roman/English phonetics.
  static String romanize(String text) {
    if (!containsDevanagari(text)) return text;

    final buffer = StringBuffer();
    final runes = text.runes.toList();

    for (int i = 0; i < runes.length; i++) {
      final ch = String.fromCharCode(runes[i]);

      // Check vowels
      if (_vowels.containsKey(ch)) {
        buffer.write(_vowels[ch]);
        continue;
      }

      // Check consonants
      if (_consonants.containsKey(ch)) {
        final roman = _consonants[ch]!;
        final nextChar = (i + 1 < runes.length) ? String.fromCharCode(runes[i + 1]) : '';

        // If next char is a matra
        if (_matras.containsKey(nextChar)) {
          buffer.write(roman);
          buffer.write(_matras[nextChar]);
          i++; // skip matra
        } else if (nextChar == '्') {
          // Virama / Halant - no inherent vowel
          buffer.write(roman);
          i++; // skip halant
        } else if (_consonants.containsKey(nextChar) || nextChar == ' ') {
          // Inherent 'a'
          buffer.write('${roman}a');
        } else {
          buffer.write(roman);
        }
        continue;
      }

      // Check standalone matras
      if (_matras.containsKey(ch)) {
        buffer.write(_matras[ch]);
        continue;
      }

      // Leave punctuation, spaces, English as is
      buffer.write(ch);
    }

    return buffer.toString();
  }
}
