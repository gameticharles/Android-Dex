import 'package:flutter/material.dart';
import 'package:adb_device_manager/features/phone/services/call_state_service.dart';

class IncomingCallBanner extends StatelessWidget {
  const IncomingCallBanner({super.key});

  String _formatDuration(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallStateData>(
      valueListenable: CallStateService.currentCallState,
      builder: (context, callData, _) {
        if (callData.state == "IDLE") {
          return const SizedBox.shrink();
        }

        final isRinging = callData.state == "RINGING";
        final name = callData.name.isNotEmpty ? callData.name : "Sophia";
        final subtitle = isRinging
            ? (callData.location.isNotEmpty ? callData.location : "Shenzhen")
            : _formatDuration(callData.durationSec);

        return Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF3F6FB), Color(0xFFE8EEF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              children: [
                // Left Title & Subtitle Info
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRinging) ...[
                      // 1. Red Decline Button
                      InkWell(
                        onTap: () => CallStateService.endCall(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33EF4444),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // 2. Green Accept Button
                      InkWell(
                        onTap: () => CallStateService.answerCall(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x3322C55E),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ] else ...[
                      // 1. Speaker Toggle Button (Black)
                      InkWell(
                        onTap: () => CallStateService.toggleSpeaker(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: callData.isSpeakerOn
                                ? const Color(0xFF00BFA5)
                                : const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Icon(
                            callData.isSpeakerOn
                                ? Icons.volume_up_rounded
                                : Icons.volume_up_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // 2. Red End Call Button
                      InkWell(
                        onTap: () => CallStateService.endCall(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33EF4444),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
