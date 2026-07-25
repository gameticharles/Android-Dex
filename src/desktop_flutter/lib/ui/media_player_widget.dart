import 'package:flutter/material.dart';

class MediaPlayerWidget extends StatefulWidget {
  const MediaPlayerWidget({super.key});

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  bool _isPlaying = false;
  double _volume = 0.7;
  double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note, color: Colors.purpleAccent),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Now Streaming Audio",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Android Dex Audio Engine (Fast Mode)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: const Color(0xFF00BFA5),
                  size: 36,
                ),
                onPressed: () => setState(() => _isPlaying = !_isPlaying),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Color(0xFF00BFA5),
              inactiveTrackColor: Colors.white10,
              thumbColor: Color(0xFF00BFA5),
            ),
            child: Slider(
              value: _progress,
              onChanged: (v) => setState(() => _progress = v),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.grey, size: 18),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 2,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                    activeTrackColor: Colors.purpleAccent,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.purpleAccent,
                  ),
                  child: Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.grey, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
