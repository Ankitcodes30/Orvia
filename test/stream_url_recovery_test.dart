import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/services/player/player_error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stream URL Recovery - Error Categorization (P2)', () {
    late PlayerErrorHandler errorHandler;

    setUp(() {
      errorHandler = PlayerErrorHandler();
    });

    tearDown(() {
      errorHandler.dispose();
    });

    test('categorizes HTTP 401 as sourceExpired', () {
      const error = 'Server returned HTTP 401 Unauthorized';
      expect(
        errorHandler.categorizeError(error),
        equals(PlayerErrorType.sourceExpired),
      );
    });

    test('categorizes "unauthorized" as sourceExpired', () {
      const error = 'Token expired: unauthorized access to stream';
      expect(
        errorHandler.categorizeError(error),
        equals(PlayerErrorType.sourceExpired),
      );
    });

    test('categorizes HTTP 403 and forbidden as sourceExpired', () {
      expect(
        errorHandler.categorizeError('HTTP 403: Forbidden stream url'),
        equals(PlayerErrorType.sourceExpired),
      );
      expect(
        errorHandler.categorizeError('Access forbidden by provider'),
        equals(PlayerErrorType.sourceExpired),
      );
    });

    test('categorizes HTTP 410 and expired as sourceExpired', () {
      expect(
        errorHandler.categorizeError('HTTP 410 Gone - resource link expired'),
        equals(PlayerErrorType.sourceExpired),
      );
      expect(
        errorHandler.categorizeError('Playback signature expired'),
        equals(PlayerErrorType.sourceExpired),
      );
    });

    test('categorizes 404 and format issues as sourceError', () {
      expect(
        errorHandler.categorizeError('HTTP 404 Not Found'),
        equals(PlayerErrorType.sourceError),
      );
      expect(
        errorHandler.categorizeError('Demuxer error: unsupported format'),
        equals(PlayerErrorType.sourceError),
      );
    });

    test('categorizes network disconnects as networkDropped', () {
      expect(
        errorHandler.categorizeError('Connection refused by peer'),
        equals(PlayerErrorType.networkDropped),
      );
      expect(
        errorHandler.categorizeError('SocketException: OS Error 110: Connection timed out'),
        equals(PlayerErrorType.networkDropped),
      );
    });
  });

  group('Stream URL Recovery - Lifecycle and Single-Retry Behavior (P2)', () {
    late PlayerErrorHandler errorHandler;
    const testTrack = Track(
      id: 'test_plugin:track_123',
      title: 'Echoes of Tomorrow',
      artists: [ArtistSummary(id: 'artist_1', name: 'Ambient Sound')],
      thumbnail: Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    setUp(() {
      errorHandler = PlayerErrorHandler();
    });

    tearDown(() {
      errorHandler.dispose();
    });

    test('invokes onClearCachedSource when sourceExpired occurs', () {
      String? clearedTrackId;
      errorHandler.onClearCachedSource = (trackId) {
        clearedTrackId = trackId;
      };

      errorHandler.registerAttempt(testTrack.id);
      errorHandler.handleError(
        PlayerErrorType.sourceExpired,
        'HTTP 401 Unauthorized',
        testTrack,
      );

      expect(clearedTrackId, equals(testTrack.id));
    });

    test('does NOT invoke onClearCachedSource for networkDropped', () {
      String? clearedTrackId;
      errorHandler.onClearCachedSource = (trackId) {
        clearedTrackId = trackId;
      };

      errorHandler.registerAttempt(testTrack.id);
      errorHandler.handleError(
        PlayerErrorType.networkDropped,
        'Offline',
        testTrack,
      );

      expect(clearedTrackId, isNull);
    });

    test('allows at most ONE automatic retry for sourceExpired', () async {
      int retryCount = 0;
      bool skipToNextTriggered = false;

      errorHandler.onRetryCurrentTrack = () {
        retryCount++;
      };

      errorHandler.onSkipToNext = () {
        skipToNextTriggered = true;
      };

      // Attempt 1: First playback attempt fails with 403/401 expired stream
      errorHandler.registerAttempt(testTrack.id);
      errorHandler.handleError(
        PlayerErrorType.sourceExpired,
        'HTTP 403 Forbidden',
        testTrack,
      );

      // Wait for any microtask/timer to execute
      await Future.delayed(const Duration(milliseconds: 50));
      expect(retryCount, equals(1), reason: 'First failure must trigger exactly one retry');
      expect(skipToNextTriggered, isFalse);

      // Attempt 2: Fresh resolution attempt was tried and failed again
      errorHandler.registerAttempt(testTrack.id);
      errorHandler.handleError(
        PlayerErrorType.sourceExpired,
        'HTTP 403 Forbidden on fresh link',
        testTrack,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      // Retry count must STILL be 1 — no second retry allowed for sourceExpired!
      expect(retryCount, equals(1), reason: 'Second failure must NOT retry again');
      expect(skipToNextTriggered, isTrue, reason: 'Failure after 1 retry must skip to next track');
    });

    test('resets retry count when new track ID is registered', () async {
      int retryCount = 0;
      errorHandler.onRetryCurrentTrack = () {
        retryCount++;
      };

      // Track 1 fails and retries once
      errorHandler.registerAttempt('track_1');
      errorHandler.handleError(
        PlayerErrorType.sourceExpired,
        'Expired',
        testTrack,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(retryCount, equals(1));

      // New Track 2 is registered
      const track2 = Track(
        id: 'track_2',
        title: 'New Song',
        artists: [],
        thumbnail: Artwork(url: 'https://example.com/art2.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );
      errorHandler.registerAttempt('track_2');

      // Track 2 fails with 401 — should get its own 1 retry
      errorHandler.handleError(
        PlayerErrorType.sourceExpired,
        'HTTP 401',
        track2,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(retryCount, equals(2));
    });
  });
}
