import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/ai.dart';
import '../models/medication.dart';
import '../state/app_state.dart';
import '../utils/schedule.dart';

/// Entry helper to launch Visual Verification Mode.
Future<void> showVisualVerificationScreen(
  BuildContext context, {
  Medication? targetMedication,
  VisualVerificationStatus initialStatus = VisualVerificationStatus.identifying,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => VisualVerificationScreen(
        targetMedication: targetMedication,
        initialStatus: initialStatus,
      ),
      fullscreenDialog: true,
    ),
  );
}

/// Camera-first visual medication verification screen matching the 3-state Certo safety model.
class VisualVerificationScreen extends StatefulWidget {
  const VisualVerificationScreen({
    super.key,
    this.targetMedication,
    this.initialStatus = VisualVerificationStatus.identifying,
  });

  final Medication? targetMedication;
  final VisualVerificationStatus initialStatus;

  @override
  State<VisualVerificationScreen> createState() =>
      _VisualVerificationScreenState();
}

class _VisualVerificationScreenState extends State<VisualVerificationScreen>
    with SingleTickerProviderStateMixin {
  late VisualVerificationStatus _status;
  bool _flashOn = false;
  bool _isProcessing = false;

  // Verification details
  String _identifiedName = 'Amoxicillin 500mg';
  String _category = 'Antibiotic · Oral tablet';
  String _matchMessage = 'This is your medication. It\'s scheduled for now.';
  String _expectedName = 'Amoxicillin 500mg';
  String _nextDoseTime = '9:00 AM';
  String _nextDoseInstruction = '1 tablet · After meal';

  late final AnimationController _scanAnimCtrl;
  late final Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;

    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _scanAnimCtrl, curve: Curves.easeInOut),
    );

    _initFromSchedule();
  }

  void _initFromSchedule() {
    final appState = Provider.of<AppState>(context, listen: false);
    final active = appState.medicationsWithStatus(MedicationStatus.active);

    final target = widget.targetMedication ??
        (active.isNotEmpty ? active.first : null);

    if (target != null) {
      _identifiedName = target.name;
      _expectedName = target.name;
      _category = target.category.isNotEmpty
          ? target.category
          : 'Oral prescription';
      _nextDoseTime = target.firstTime;
      _nextDoseInstruction = target.dosageLine;
    } else {
      _identifiedName = 'Amoxicillin 500mg';
      _expectedName = 'Amoxicillin 500mg';
      _category = 'Antibiotic · Oral tablet';
      _nextDoseTime = '9:00 AM';
      _nextDoseInstruction = '1 tablet · After meal';
    }
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    super.dispose();
  }

  /// Simulates taking a photo and running the AI visual verification model.
  Future<void> _captureAndAnalyze([VisualVerificationStatus? forcedState]) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _status = VisualVerificationStatus.identifying;
    });

    // Register tool callback to capture result from AI if called
    final appState = Provider.of<AppState>(context, listen: false);

    // Simulate camera shutter & AI processing latency
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    if (forcedState != null) {
      setState(() {
        _isProcessing = false;
        _status = forcedState;
      });
      return;
    }

    // Inspect schedule to determine realistic match
    final dues = dueDoses(appState.medications, DateTime.now());
    final dueNow = dues.isNotEmpty ? dues.first.medication : null;

    if (dueNow != null) {
      setState(() {
        _isProcessing = false;
        _status = VisualVerificationStatus.confirmedMatch;
        _identifiedName = dueNow.name;
        _expectedName = dueNow.name;
        _category = dueNow.category.isNotEmpty
            ? dueNow.category
            : 'Antibiotic · Oral tablet';
        _nextDoseTime = dues.first.time;
        _nextDoseInstruction = dueNow.dosageLine;
        _matchMessage = 'This is your medication. It\'s scheduled for now.';
      });
    } else {
      // Demo match
      setState(() {
        _isProcessing = false;
        _status = VisualVerificationStatus.confirmedMatch;
        _identifiedName = _expectedName;
      });
    }
  }

  void _onConfirmDose() {
    final appState = Provider.of<AppState>(context, listen: false);
    final med = findMedication(appState, name: _identifiedName);
    if (med != null) {
      appState.markTaken(med.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Marked "$_identifiedName" as taken.'),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Viewfinder (Realistic Scene) ──────────────────────────
          Positioned.fill(
            child: _ViewfinderBackground(flashOn: _flashOn),
          ),

          // ── Reticle dashed blue box with subtle scan line ────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            left: 24,
            right: 24,
            height: MediaQuery.of(context).size.height * 0.28,
            child: AnimatedBuilder(
              animation: _scanAnimCtrl,
              builder: (context, _) => _ScannerReticle(
                scanLineProgress: _status == VisualVerificationStatus.identifying
                    ? _scanLineAnim.value
                    : null,
              ),
            ),
          ),

          // ── Top Header Controls (Close & Flash) ──────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundHeaderBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _RoundHeaderBtn(
                    icon: _flashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: () => setState(() => _flashOn = !_flashOn),
                  ),
                ],
              ),
            ),
          ),

          // ── Demo State Quick Switcher (Top Right Sub-bar) ─────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 58,
            right: 20,
            child: _DemoStatePicker(
              currentStatus: _status,
              onSelect: (st) => _captureAndAnalyze(st),
            ),
          ),

          // ── Bottom Sheet (The 4 Distinct States) ────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: _VerificationBottomSheet(
              status: _status,
              isProcessing: _isProcessing,
              identifiedName: _identifiedName,
              category: _category,
              matchMessage: _matchMessage,
              expectedName: _expectedName,
              nextDoseTime: _nextDoseTime,
              nextDoseInstruction: _nextDoseInstruction,
              onCapture: () => _captureAndAnalyze(),
              onConfirm: _onConfirmDose,
              onScanAnother: () => setState(() {
                _status = VisualVerificationStatus.identifying;
              }),
              onTryAgain: () => setState(() {
                _status = VisualVerificationStatus.identifying;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Viewfinder Background & Reticle
// ─────────────────────────────────────────────────────────────────────────────

class _ViewfinderBackground extends StatelessWidget {
  const _ViewfinderBackground({required this.flashOn});

  final bool flashOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2430),
        image: const DecorationImage(
          // Uses an artistic warm-lit desk composition representation
          image: AssetImage('assets/icon.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          opacity: 0.15,
        ),
      ),
      child: CustomPaint(
        painter: _TablePillboxPainter(flashOn: flashOn),
      ),
    );
  }
}

class _TablePillboxPainter extends CustomPainter {
  const _TablePillboxPainter({required this.flashOn});
  final bool flashOn;

  @override
  void paint(Canvas canvas, Size size) {
    // Warm background sunlight gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF655B51),
          const Color(0xFFBCA68E),
          const Color(0xFFD6C1A9),
          const Color(0xFF9F8367),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (flashOn) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..blendMode = BlendMode.screen;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), flashPaint);
    }

    // Glass of water in top right
    final glassPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final glassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.72, size.height * 0.22, 54, 85),
      const Radius.circular(8),
    );
    canvas.drawRRect(glassRect, glassPaint);

    // 7-day pill organizer container in center
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.27,
        size.width * 0.76,
        size.height * 0.11,
      ),
      const Radius.circular(12),
    );

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(boxRect.shift(const Offset(4, 10)), shadowPaint);

    // Pillbox body (white/frosted)
    final boxPaint = Paint()..color = const Color(0xFFF7F8F9);
    canvas.drawRRect(boxRect, boxPaint);

    final boxBorder = Paint()
      ..color = const Color(0xFFD3D8E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(boxRect, boxBorder);

    // 7 compartment divisions
    final compWidth = (size.width * 0.76) / 7;
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    for (int i = 0; i < 7; i++) {
      final x = size.width * 0.12 + (i * compWidth);
      if (i > 0) {
        canvas.drawLine(
          Offset(x, size.height * 0.27),
          Offset(x, size.height * 0.38),
          boxBorder,
        );
      }

      // Draw day label text
      final textPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x + 5, size.height * 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TablePillboxPainter oldDelegate) =>
      oldDelegate.flashOn != flashOn;
}

class _ScannerReticle extends StatelessWidget {
  const _ScannerReticle({this.scanLineProgress});

  final double? scanLineProgress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedReticlePainter(scanLineProgress: scanLineProgress),
    );
  }
}

class _DashedReticlePainter extends CustomPainter {
  const _DashedReticlePainter({this.scanLineProgress});
  final double? scanLineProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF3366FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    // Draw dashed path around the rrect
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    const dashWidth = 14.0;
    const dashSpace = 8.0;

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, borderPaint);
        distance += dashWidth + dashSpace;
      }
    }

    // Laser / scanning beam line
    if (scanLineProgress != null) {
      final y = size.height * scanLineProgress!;
      final laserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.9),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4))
        ..strokeWidth = 2;

      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), laserPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedReticlePainter oldDelegate) =>
      oldDelegate.scanLineProgress != scanLineProgress;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom Sheet matching the 4 screenshots
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationBottomSheet extends StatelessWidget {
  const _VerificationBottomSheet({
    required this.status,
    required this.isProcessing,
    required this.identifiedName,
    required this.category,
    required this.matchMessage,
    required this.expectedName,
    required this.nextDoseTime,
    required this.nextDoseInstruction,
    required this.onCapture,
    required this.onConfirm,
    required this.onScanAnother,
    required this.onTryAgain,
  });

  final VisualVerificationStatus status;
  final bool isProcessing;
  final String identifiedName;
  final String category;
  final String matchMessage;
  final String expectedName;
  final String nextDoseTime;
  final String nextDoseInstruction;
  final VoidCallback onCapture;
  final VoidCallback onConfirm;
  final VoidCallback onScanAnother;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content according to the 4 states
          switch (status) {
            VisualVerificationStatus.identifying => _buildIdentifyingState(),
            VisualVerificationStatus.confirmedMatch =>
              _buildConfirmedMatchState(),
            VisualVerificationStatus.confirmedMismatch =>
              _buildConfirmedMismatchState(),
            VisualVerificationStatus.uncertain => _buildUncertainState(),
          },
        ],
      ),
    );
  }

  // ── State 1: Identifying ──────────────────────────────────────────────────
  Widget _buildIdentifyingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF3366FF),
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF3366FF),
                    size: 20,
                  ),
            const SizedBox(width: 8),
            Text(
              isProcessing
                  ? 'Analyzing medication image...'
                  : 'Identifying medication...',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Point at the package and keep it steady.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),

        // Shutter Button
        GestureDetector(
          onTap: isProcessing ? null : onCapture,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF3366FF),
                width: 3.5,
              ),
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3366FF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ── State 2: Confirmed Match (Screen 2 in picture) ─────────────────────────
  Widget _buildConfirmedMatchState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Identified Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                identifiedName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA3E7C3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF0E9347),
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Identified',
                    style: TextStyle(
                      color: Color(0xFF0E9347),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          category,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),

        // Green match pill banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF8F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF15803D),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  matchMessage,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Next dose card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEXT DOSE',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF3366FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nextDoseTime,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    nextDoseInstruction,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Primary Confirm button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onConfirm,
            child: const Text(
              'Confirm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Scan another text button
        Center(
          child: TextButton(
            onPressed: onScanAnother,
            child: const Text(
              'Scan another',
              style: TextStyle(
                color: Color(0xFF3366FF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── State 3: Confirmed Mismatch (Screen 3 in picture) ──────────────────────
  Widget _buildConfirmedMismatchState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Red warning rounded square icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF04438),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.warning_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Not your medication',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'This isn\'t the medication scheduled for now. Please scan another package.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),

        // YOU NEED card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOU NEED',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    expectedName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    nextDoseInstruction,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Try again button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onTryAgain,
            child: const Text(
              'Try again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── State 4: Uncertain (Screen 4 in picture) ───────────────────────────────
  Widget _buildUncertainState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Purple question rounded square icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF8B6BF6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'I\'m not sure',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'I can\'t identify this medication confidently. Please move closer and scan it again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),

        // Try again button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onTryAgain,
            child: const Text(
              'Try again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Header Circular Button (Close & Flash)
// ─────────────────────────────────────────────────────────────────────────────

class _RoundHeaderBtn extends StatelessWidget {
  const _RoundHeaderBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Demo State Quick Switcher
// ─────────────────────────────────────────────────────────────────────────────

class _DemoStatePicker extends StatelessWidget {
  const _DemoStatePicker({
    required this.currentStatus,
    required this.onSelect,
  });

  final VisualVerificationStatus currentStatus;
  final ValueChanged<VisualVerificationStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge('Match', VisualVerificationStatus.confirmedMatch, const Color(0xFF10B981)),
          _badge('Mismatch', VisualVerificationStatus.confirmedMismatch, const Color(0xFFEF4444)),
          _badge('Uncertain', VisualVerificationStatus.uncertain, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _badge(String label, VisualVerificationStatus st, Color color) {
    final active = currentStatus == st;
    return GestureDetector(
      onTap: () => onSelect(st),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
