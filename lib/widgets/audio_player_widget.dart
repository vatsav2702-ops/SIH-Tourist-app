import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String spotName;

  const AudioPlayerWidget({
    Key? key,
    required this.audioUrl,
    required this.spotName,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late HeritageAudioService _audioService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _audioService = HeritageAudioService();
    _audioService.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _audioService.initListeners();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    num minutes = d.inMinutes;
    num seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayPause() async {
    if (_audioService.playerState == PlayerState.playing) {
      await _audioService.pauseAudio();
    } else {
      setState(() => _isLoading = true);
      await _audioService.playAudio(widget.audioUrl);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPlaying = _audioService.playerState == PlayerState.playing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HERITAGE AUDIO GUIDE',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.spotName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2.5),
                )
              else
                IconButton(
                  onPressed: _togglePlayPause,
                  iconSize: 44,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: Colors.tealAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: Colors.tealAccent,
              activeTrackColor: Colors.tealAccent,
              inactiveTrackColor: Colors.white24,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              min: 0,
              max: _audioService.duration.inSeconds > 0
                  ? _audioService.duration.inSeconds.toDouble()
                  : 100,
              value: _audioService.position.inSeconds
                  .clamp(0, _audioService.duration.inSeconds > 0 ? _audioService.duration.inSeconds : 100)
                  .toDouble(),
              onChanged: (val) {
                _audioService.seekAudio(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_audioService.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  _formatDuration(_audioService.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
