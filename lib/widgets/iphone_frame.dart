import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../web/web_frame_config.dart';

/// A polished iPhone-style bezel that hosts [child] at phone logical size.
class IPhoneFrame extends StatelessWidget {
  const IPhoneFrame({
    super.key,
    required this.child,
    this.maxHeight,
  });

  final Widget child;
  final double? maxHeight;

  static const double _bezel = 12;
  static const double _radius = 52;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxH = maxHeight ?? (screen.height - 48);
    final scale = math.min(
      1.0,
      math.min(
        (screen.width * 0.42) / kDemoPhoneSize.width,
        (maxH - 24) / (kDemoPhoneSize.height + _bezel * 2),
      ),
    ).clamp(0.55, 1.0);
    final phoneW = kDemoPhoneSize.width * scale;
    final phoneH = kDemoPhoneSize.height * scale;
    final bezel = _bezel * scale;
    final radius = _radius * scale;
    final islandW = 126.0 * scale;
    final islandH = 37.0 * scale;

    return SizedBox(
      width: phoneW + bezel * 2 + 18 * scale,
      height: phoneH + bezel * 2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.28),
                    blurRadius: 48 * scale,
                    spreadRadius: 2,
                    offset: Offset(0, 18 * scale),
                  ),
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    blurRadius: 80 * scale,
                    spreadRadius: -8,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 120 * scale,
            child: _SideButton(
              width: 4 * scale,
              height: 32 * scale,
              radius: 2 * scale,
            ),
          ),
          Positioned(
            left: 0,
            top: 168 * scale,
            child: _SideButton(
              width: 4 * scale,
              height: 56 * scale,
              radius: 2 * scale,
            ),
          ),
          Positioned(
            left: 0,
            top: 236 * scale,
            child: _SideButton(
              width: 4 * scale,
              height: 56 * scale,
              radius: 2 * scale,
            ),
          ),
          Positioned(
            right: 0,
            top: 200 * scale,
            child: _SideButton(
              width: 4 * scale,
              height: 88 * scale,
              radius: 2 * scale,
            ),
          ),
          Container(
            width: phoneW + bezel * 2,
            height: phoneH + bezel * 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2D35),
                  Color(0xFF0E0F12),
                  Color(0xFF1A1C22),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFF3A3D46),
                width: math.max(1.0, 1.5 * scale),
              ),
            ),
            padding: EdgeInsets.all(bezel),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - bezel * 0.85),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: kDemoPhoneSize,
                      devicePixelRatio: 3,
                      padding: const EdgeInsets.only(top: 54, bottom: 28),
                      viewPadding: const EdgeInsets.only(top: 54, bottom: 28),
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: kDemoPhoneSize.width,
                        height: kDemoPhoneSize.height,
                        child: child,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 11 * scale,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: islandW,
                          height: islandH,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(islandH),
                          ),
                          child: Align(
                            alignment: const Alignment(0.55, 0),
                            child: Container(
                              width: math.max(8, 10 * scale),
                              height: math.max(8, 10 * scale),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A1A1A),
                                border: Border.all(
                                  color: const Color(0xFF0A2540),
                                  width: math.max(1, 1.5 * scale),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.18],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E24),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF3A3D46), width: 0.5),
      ),
    );
  }
}
