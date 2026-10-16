import 'package:Orvia/services/orvia_player.dart';
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
part 'orvia_player_state.dart';

class OrviaPlayerCubit extends Cubit<OrviaPlayerState> {
  final OrviaMusicPlayer orviaPlayer;
  late ValueStream<ProgressBarStreams> progressStreams;

  OrviaPlayerCubit(this.orviaPlayer)
      : super(OrviaPlayerState(isReady: true)) {
    orviaPlayer.syncPublicState();
    _setupProgressStreams();
  }

  void switchShowLyrics({bool? value}) {
    emit(OrviaPlayerState(
        isReady: true, showLyrics: value ?? !state.showLyrics));
  }

  void _setupProgressStreams() {
    progressStreams = Rx.combineLatest4(
      orviaPlayer.positionStream,
      orviaPlayer.durationStream,
      orviaPlayer.bufferedStream,
      orviaPlayer.playingStream,
      (Duration position, Duration duration, Duration buffered, bool playing) =>
          ProgressBarStreams(
        position: position,
        duration: duration,
        buffered: buffered,
        isPlaying: playing,
      ),
    ).shareValueSeeded(
      ProgressBarStreams(
        position: Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> close() {
    // Intentionally does NOT stop the player.
    // The AudioService foreground service manages its own lifecycle via
    // onTaskRemoved() / onNotificationDeleted().
    return super.close();
  }
}
