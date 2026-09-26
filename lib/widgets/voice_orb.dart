import 'package:flutter/material.dart';
import 'package:flutter_thinking_orbs/flutter_thinking_orbs.dart';

/// High-level voice conversation phases that drive orb animation & position.
enum VoiceOrbPhase {
  /// Full-screen centered orb — waiting for speech.
  active,

  /// User is talking; orb reacts to mic amplitude.
  speaking,

  /// AI is processing / running tools.
  processing,

  /// AI is speaking aloud (calm response animation).
  responding,

  /// Orb tucked near the top; chat transcript visible below.
  chat,
}

/// Maps a conversational phase to a [ThinkingOrb] animation state.
OrbState orbStateForPhase(VoiceOrbPhase phase) {
  return switch (phase) {
    VoiceOrbPhase.active => OrbState.listening,
    VoiceOrbPhase.speaking => OrbState.listening,
    VoiceOrbPhase.processing => OrbState.working,
    VoiceOrbPhase.responding => OrbState.composing,
    VoiceOrbPhase.chat => OrbState.shaping,
  };
}

/// Modular voice orb — swap the inner animation without rewriting chat UI.
///
/// Size and vertical placement are controlled by the parent via [phase]
/// transitions; this widget only paints the orb itself and applies
/// audio-reactive scale when [phase] is [VoiceOrbPhase.speaking].
class VoiceOrb extends StatelessWidget {
  const VoiceOrb({
    super.key,
    required this.phase,
    this.amplitude = 0,
    this.size = 160,
    this.onTap,
  });

  final VoiceOrbPhase phase;
  final double amplitude;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Smooth audio-reactive scale: quiet ≈ 1.0, loud ≈ 1.22.
    final reactiveScale = phase == VoiceOrbPhase.speaking
        ? 1.0 + (amplitude.clamp(0.0, 1.0) * 0.22)
        : 1.0;

    final speed = switch (phase) {
      VoiceOrbPhase.speaking => 1.35,
      VoiceOrbPhase.processing => 1.15,
      VoiceOrbPhase.responding => 0.9,
      VoiceOrbPhase.chat => 0.7,
      VoiceOrbPhase.active => 1.0,
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: reactiveScale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: size,
          height: size,
          child: ThinkingOrb(
            state: orbStateForPhase(phase),
            size: size,
            theme: OrbTheme.light,
            speed: speed,
            semanticLabel: switch (phase) {
              VoiceOrbPhase.active => 'Ready to listen',
              VoiceOrbPhase.speaking => 'Listening to you',
              VoiceOrbPhase.processing => 'Thinking',
              VoiceOrbPhase.responding => 'Speaking',
              VoiceOrbPhase.chat => 'Conversation',
            },
          ),
        ),
      ),
    );
  }
}
