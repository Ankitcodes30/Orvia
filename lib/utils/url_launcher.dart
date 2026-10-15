import 'dart:developer';

import 'package:url_launcher/url_launcher.dart' as url_launcher;

Future<void> launchUrl(Uri url) async {
  if (!await url_launcher.launchUrl(url,
      mode: url_launcher.LaunchMode.externalApplication)) {
    log('Could not launch $url', name: 'launchUrl');
  }
}
