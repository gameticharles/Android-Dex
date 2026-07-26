import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/device_state.dart';
import '../services/app_launcher_service.dart';
import '../services/real_adb_sync_service.dart';
import 'smart_app_icon_widget.dart';

class MediaPlayerWidget extends StatelessWidget {
  final DeviceState? deviceState;

  const MediaPlayerWidget({super.key, this.deviceState});

  @override
  Widget build(BuildContext context) {
    return MediaPlayerFlyout(deviceState: deviceState);
  }
}

class MediaPlayerFlyout extends StatefulWidget {
  final DeviceState? deviceState;

  const MediaPlayerFlyout({super.key, this.deviceState});

  @override
  State<MediaPlayerFlyout> createState() => _MediaPlayerFlyoutState();
}

class _MediaPlayerFlyoutState extends State<MediaPlayerFlyout> {
  bool _isMuted = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  double _volume = 0.75;

  Timer? _playbackTicker;
  int _currentPosMs = 0;
  bool _isDraggingSlider = false;
  double _dragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _syncPlaybackState();
  }

  @override
  void dispose() {
    _playbackTicker?.cancel();
    super.dispose();
  }

  void _syncPlaybackState() {
    final media = widget.deviceState?.mediaState.value ?? const RealMediaState();
    if (!_isDraggingSlider) {
      _currentPosMs = media.positionMs;
    }
    _manageTicker(media.isPlaying, media.durationMs);
  }

  void _manageTicker(bool isPlaying, int durationMs) {
    if (isPlaying) {
      if (_playbackTicker == null || !_playbackTicker!.isActive) {
        _playbackTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            final curMedia = widget.deviceState?.mediaState.value ?? const RealMediaState();
            if (curMedia.isPlaying && !_isDraggingSlider) {
              final maxMs = curMedia.durationMs > 0 ? curMedia.durationMs : 225000;
              setState(() {
                if (_currentPosMs < maxMs) {
                  _currentPosMs += 1000;
                }
              });
            }
          }
        });
      }
    } else {
      _playbackTicker?.cancel();
      _playbackTicker = null;
    }
  }

  String _formatTimeFromMs(int ms) {
    if (ms <= 0) return "00:00";
    final totalSecs = ms ~/ 1000;
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  void _sendMediaKey(int keyCode) {
    AppLauncherService.sendKeyEvent(keyCode);
  }

  Widget _buildArtworkWidget(RealMediaState media) {
    if (media.artworkBase64 != null && media.artworkBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(media.artworkBase64!);
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    } else if (media.artworkUrl != null && media.artworkUrl!.isNotEmpty) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            media.artworkUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackArtwork(media.packageName),
          ),
        ),
      );
    }

    return _buildFallbackArtwork(media.packageName);
  }

  Widget _buildFallbackArtwork(String pkg) {
    if (pkg.isNotEmpty) {
      return SmartAppIconWidget(
        packageName: pkg,
        size: 54,
        borderRadius: 12,
      );
    }
    return Container(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.deviceState != null
        ? ValueListenableBuilder<RealMediaState>(
            valueListenable: widget.deviceState!.mediaState,
            builder: (context, media, _) {
              if (!_isDraggingSlider) {
                _currentPosMs = media.positionMs;
              }
              _manageTicker(media.isPlaying, media.durationMs);
              return _buildFlyoutBody(media);
            },
          )
        : _buildFlyoutBody(const RealMediaState());
  }

  Widget _buildFlyoutBody(RealMediaState media) {
    final bool isPlaying = media.isPlaying;
    final String title = media.title.isNotEmpty ? media.title : "Starlight Horizon";
    final String artist = media.artist.isNotEmpty ? media.artist : "Android DEX Audio Engine";
    final String album = media.album;
    final int totalDurationMs = media.durationMs > 0 ? media.durationMs : 225000;

    final double currentProgress = _isDraggingSlider
        ? _dragProgress
        : (_currentPosMs / totalDurationMs).clamp(0.0, 1.0);
    final int displayPosMs = _isDraggingSlider
        ? (_dragProgress * totalDurationMs).round()
        : _currentPosMs;

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
                child: Text(
                  isPlaying ? "Playing on Device" : "Paused",
                  style: const TextStyle(
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
                _buildArtworkWidget(media),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (album.isNotEmpty && album != title && album != artist)
                            ? "$artist • $album"
                            : artist,
                        style: const TextStyle(
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
                  value: currentProgress,
                  onChangeStart: (v) {
                    setState(() {
                      _isDraggingSlider = true;
                      _dragProgress = v;
                    });
                  },
                  onChanged: (v) {
                    setState(() {
                      _dragProgress = v;
                    });
                  },
                  onChangeEnd: (v) {
                    final targetMs = (v * totalDurationMs).round();
                    setState(() {
                      _isDraggingSlider = false;
                      _currentPosMs = targetMs;
                    });
                    RealAdbSyncService.seekMedia(targetMs);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTimeFromMs(displayPosMs),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                    Text(
                      _formatTimeFromMs(totalDurationMs),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
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
                  _sendMediaKey(88); // KEYCODE_MEDIA_PREVIOUS
                  setState(() => _currentPosMs = 0);
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
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    if (widget.deviceState != null) {
                      final cur = widget.deviceState!.mediaState.value;
                      widget.deviceState!.mediaState.value = cur.copyWith(
                        isPlaying: !cur.isPlaying,
                      );
                    }
                    _sendMediaKey(85); // KEYCODE_MEDIA_PLAY_PAUSE
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  _sendMediaKey(87); // KEYCODE_MEDIA_NEXT
                  setState(() => _currentPosMs = 0);
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
                onPressed: () {
                  _sendMediaKey(164); // KEYCODE_VOLUME_MUTE
                  setState(() => _isMuted = !_isMuted);
                },
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
                      if (v > _volume) {
                        _sendMediaKey(24); // KEYCODE_VOLUME_UP
                      } else {
                        _sendMediaKey(25); // KEYCODE_VOLUME_DOWN
                      }
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
