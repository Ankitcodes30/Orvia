/// Formats errors from plugins, network requests, or WASM executions into
/// clean, user-friendly messages without leaking URLs, technical stack traces,
/// or raw WASM details to the user.
String formatUserFriendlyPluginError(
  dynamic error, {
  String fallback = 'Failed to load content. Please try again.',
}) {
  if (error == null) return fallback;
  final msg = error.toString().toLowerCase();

  // 1. Offline / Network connectivity failures
  if (msg.contains('http request failed') ||
      msg.contains('error sending request') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('failed to resolve') ||
      msg.contains('dns error') ||
      msg.contains('client error (connect)') ||
      msg.contains('offline') ||
      msg.contains('no internet') ||
      msg.contains('socketexception') ||
      msg.contains('broken pipe') ||
      msg.contains('connection reset')) {
    return "You're offline. Connect to the internet to load this content.";
  }

  // 2. Timeouts
  if (msg.contains('timed out') ||
      msg.contains('timeout') ||
      msg.contains('deadline has elapsed')) {
    return 'Connection timed out. Please check your internet connection.';
  }

  // 3. Server errors
  if (msg.contains('500') ||
      msg.contains('502') ||
      msg.contains('503') ||
      msg.contains('504') ||
      msg.contains('internal server error') ||
      msg.contains('bad gateway') ||
      msg.contains('service unavailable')) {
    return 'Server is temporarily unavailable. Please try again later.';
  }

  // 4. Plugin lifecycle errors
  if (msg.contains('plugin is not loaded') ||
      msg.contains('plugin not found')) {
    return 'Content plugin is not loaded. Please check Plugin Manager.';
  }

  // 5. Technical strings containing URLs, WASM, or plugin internal prefixes
  if (msg.contains('wasm execution error') ||
      msg.contains('plugin_error::') ||
      msg.contains('http://') ||
      msg.contains('https://') ||
      msg.contains('.php') ||
      msg.contains('stack trace')) {
    return fallback;
  }

  // 6. Clean message without technical prefix
  final clean = error
      .toString()
      .replaceFirst(
        RegExp(r'^(Exception|PluginException|PluginExecutionException):\s*'),
        '',
      )
      .trim();
  if (clean.length < 120 && !clean.contains('://') && !clean.contains('::')) {
    return clean;
  }

  return fallback;
}

/// Checks whether an artwork or thumbnail URL represents a generic provider/platform
/// icon (e.g. Billboard app logo 'icon-512x512.png', PMC Billboard brand assets)
/// rather than genuine track or album artwork.
bool isGenericProviderIcon(String? url) {
  if (url == null || url.trim().isEmpty) return true;
  final lower = url.trim().toLowerCase();
  if (lower.contains('billboard.com') &&
      (lower.contains('icon-') ||
          lower.contains('pmc-billboard') ||
          lower.contains('app/icons') ||
          lower.contains('assets/app') ||
          lower.contains('billboard-default') ||
          lower.contains('billboard-logo'))) {
    return true;
  }
  if (lower.contains('charts-static.billboard.com/assets')) {
    return true;
  }
  if (lower.endsWith('/icon-512x512.png') || lower.endsWith('icon-512x512.png')) {
    return true;
  }
  return false;
}

