import 'dart:async';
import 'dart:developer';

import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/services/player/player_engine.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/db/dao/history_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';

/// Tracks playback of the current track and pushes it to
/// the playback history DB. Default threshold is 5 seconds.
class RecentlyPlayedTracker {
  final PlayerEngine _engine;
  final Track? Function() _getCurrentTrack;

  int _thresholdSeconds;
  double _percentThreshold;
  StreamSubscription<EngineState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  // Tracking state
  String? _trackingMediaId;
  int? _startPositionMs;
  bool _recordedForCurrent = false;
  int? _lastPositionMs;
  int? _lastPositionTimestampMs;

  RecentlyPlayedTracker(
    this._engine,
    this._getCurrentTrack, {
    int thresholdSeconds = 5,
    double percentThreshold = 0.3,
  })  : _thresholdSeconds = thresholdSeconds,
        _percentThreshold = percentThreshold {
    _stateSub = _engine.stateStream.listen(_onEngineState);
    _positionSub = _engine.positionStream.listen(_onPosition);
  }

  void _onEngineState(EngineState state) {
    final isPlaying = _engine.playing;
    final track = _getCurrentTrack();
    final mediaId = track?.id;

    if (isPlaying && state == EngineState.ready) {
      if (track == null) return;
      if (_trackingMediaId == null ||
          !TrackIdentity.isMatchingTrackId(_trackingMediaId!, mediaId ?? '')) {
        // Track switched without an explicit flush, flush the previous track
        if (_trackingMediaId != null) {
          unawaited(flushCurrentPlay());
        }
        _trackingMediaId = mediaId;
        _recordedForCurrent = false;
        _startPositionMs = _engine.position.inMilliseconds;
        _lastPositionMs = _startPositionMs;
        _lastPositionTimestampMs = DateTime.now().millisecondsSinceEpoch;
      }
    } else if (state == EngineState.completed) {
      // Track finished playing completely -> flush immediately.
      unawaited(flushCurrentPlay(force: true));
      _trackingMediaId = null;
      _startPositionMs = null;
      _lastPositionMs = null;
      _lastPositionTimestampMs = null;
    } else if (state == EngineState.idle || state == EngineState.error) {
      // Do not reset _trackingMediaId immediately so in-flight track change
      // can flush the play before the new track starts.
    }
  }

  Future<void> _onPosition(Duration position) async {
    if (_trackingMediaId == null || _recordedForCurrent) return;

    final track = _getCurrentTrack();
    if (track == null ||
        !TrackIdentity.isMatchingTrackId(track.id, _trackingMediaId!)) {
      _trackingMediaId = null;
      _startPositionMs = null;
      return;
    }

    final currMs = position.inMilliseconds;
    final startMs = _startPositionMs ?? currMs;
    if (currMs < startMs) {
      _startPositionMs = currMs;
      _lastPositionMs = currMs;
      _lastPositionTimestampMs = DateTime.now().millisecondsSinceEpoch;
      return;
    }

    final nowTs = DateTime.now().millisecondsSinceEpoch;
    if (_lastPositionMs != null && _lastPositionTimestampMs != null) {
      final posDelta = currMs - _lastPositionMs!;
      final timeDelta = nowTs - _lastPositionTimestampMs!;
      if (posDelta > timeDelta + 1000) {
        _startPositionMs = currMs;
        _lastPositionMs = currMs;
        _lastPositionTimestampMs = nowTs;
        return;
      }
    }
    _lastPositionMs = currMs;
    _lastPositionTimestampMs = nowTs;

    final elapsedMs = currMs - startMs;

    final bool reachedTimeThreshold = elapsedMs >= _thresholdSeconds * 1000;
    final durationMs = track.durationMs?.toInt();
    final bool reachedPercentThreshold =
        durationMs != null && durationMs > 0
            ? currMs >= (durationMs * _percentThreshold)
            : false;

    if (reachedTimeThreshold || reachedPercentThreshold) {
      _recordedForCurrent = true;
      try {
        final trackDao = TrackDAO(DBProvider.db);
        final historyDao = HistoryDAO(DBProvider.db, trackDao);
        await historyDao.recordPlay(track);
        log('Tracked play for ${track.id}', name: 'RecentlyPlayedTracker');
      } catch (e) {
        log('Failed to record play: $e', name: 'RecentlyPlayedTracker');
      }
    }
  }

  /// Commits the current playback to History if played for at least 3 seconds or 10%
  Future<void> flushCurrentPlay({bool force = false}) async {
    if (_recordedForCurrent || _trackingMediaId == null) return;
    final track = _getCurrentTrack();
    if (track == null) return;

    final currMs = _engine.position.inMilliseconds;
    final startMs = _startPositionMs ?? 0;
    final elapsedMs = (currMs - startMs).abs();

    final durationMs = track.durationMs?.toInt();
    final bool reachedMinTime = elapsedMs >= 3000;
    final bool reachedPercent = durationMs != null && durationMs > 0
        ? currMs >= (durationMs * 0.1)
        : false;

    if (force || reachedMinTime || reachedPercent) {
      _recordedForCurrent = true;
      try {
        final trackDao = TrackDAO(DBProvider.db);
        final historyDao = HistoryDAO(DBProvider.db, trackDao);
        await historyDao.recordPlay(track);
        log('Flushed and tracked play for ${track.id}',
            name: 'RecentlyPlayedTracker');
      } catch (e) {
        log('Failed to flush play: $e', name: 'RecentlyPlayedTracker');
      }
    }
  }

  void setThresholdSeconds(int seconds) {
    if (seconds <= 0) return;
    _thresholdSeconds = seconds;
  }

  void setPercentThreshold(double percent) {
    if (percent <= 0 || percent > 1) return;
    _percentThreshold = percent;
  }

  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _positionSub?.cancel();
  }
}
