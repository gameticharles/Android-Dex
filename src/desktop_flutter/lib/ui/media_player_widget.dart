import 'package:flutter/material.dart';

class MediaPlayerWidget extends StatelessWidget {
  const MediaPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const MediaPlayerFlyout();
  }
}

class MediaPlayerFlyout extends StatefulWidget {
  const MediaPlayerFlyout({super.key});

  @override
  State<MediaPlayerFlyout> createState() => _MediaPlayerFlyoutState();
}

class _MediaPlayerFlyoutState extends State<MediaPlayerFlyout> {
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  double _volume = 0.75;
  double _progress = 0.42;

  String _formatTime(double progress) {
    const totalSeconds = 225; // 3:45 total duration
    final currentSeconds = (progress * totalSeconds).toInt();
    final mins = currentSeconds ~/ 60;
    final secs = currentSeconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.music_note_rounded,
                      color: Color(0xFF8B5CF6), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Media Controls",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  "Low-Latency Stream",
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Album Art & Track Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Starlight Horizon",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3),
                      Text(
                        "Android DEX Audio Engine",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress Timeline Scrubber
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: const Color(0xFF00BFA5),
                  inactiveTrackColor: Colors.white10,
                  thumbColor: const Color(0xFF00BFA5),
                  overlayColor: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _progress,
                  onChanged: (v) => setState(() => _progress = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(_progress),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                    const Text(
                      "03:45",
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Full Transport Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: _isShuffle ? const Color(0xFF00BFA5) : Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(() => _isShuffle = !_isShuffle),
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  setState(() => _progress = 0.0);
                },
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: IconButton(
                  iconSize: 28,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.black,
                  ),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  setState(() => _progress = 0.0);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.repeat_rounded,
                  color: _isRepeat ? const Color(0xFF00BFA5) : Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(() => _isRepeat = !_isRepeat),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Volume Bar
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isMuted || _volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: () => setState(() => _isMuted = !_isMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        RoundSliderThumbShape(enabledThumbRadius: 5),
                    activeTrackColor: Color(0xFF8B5CF6),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Color(0xFF8B5CF6),
                  ),
                  child: Slider(
                    value: _isMuted ? 0.0 : _volume,
                    onChanged: (v) => setState(() {
                      _volume = v;
                      _isMuted = v == 0;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${(_isMuted ? 0 : (_volume * 100)).toInt()}%",
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

