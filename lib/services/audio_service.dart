import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class HeritageAudioService {
  final AudioPlayer player = AudioPlayer();

  PlayerState playerState = PlayerState.stopped;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;

  void Function()? onStateChanged;

  void initListeners() {
    _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      playerState = state;
      if (onStateChanged != null) onStateChanged!();
    });

    _durationSubscription = player.onDurationChanged.listen((d) {
      duration = d;
      if (onStateChanged != null) onStateChanged!();
    });

    _positionSubscription = player.onPositionChanged.listen((p) {
      position = p;
      if (onStateChanged != null) onStateChanged!();
    });
  }

  Future<void> playAudio(String url) async {
    try {
      await player.stop();
      await player.play(UrlSource(url));
    } catch (_) {
      // Gracefully handle network/audio streaming errors
    }
  }

  Future<void> pauseAudio() async {
    await player.pause();
  }

  Future<void> resumeAudio() async {
    await player.resume();
  }

  Future<void> seekAudio(Duration position) async {
    await player.seek(position);
  }

  Future<void> stopAudio() async {
    await player.stop();
  }

  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    player.dispose();
  }
}
