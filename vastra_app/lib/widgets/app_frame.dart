import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/vastra_colors.dart';
import 'phone_behavior.dart';
import 'pip.dart';
import 'vastra_widgets.dart';

/// On phones the app fills the screen. On wider screens (tablets, laptops on
/// the web) it renders inside a phone-sized frame so it looks exactly like the
/// mobile app, with a QR code to open it on a phone.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    if (size.width < 600) return child;

    final available = Size(size.width >= 1020 ? 520 : size.width - 48, size.height - 48);

    return Material(
      color: VastraColors.ivory,
      child: Stack(
        children: [
          const Positioned.fill(child: VastraBackdrop()),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (size.width >= 1020) ...[const _SidePanel(), const SizedBox(width: 64)],
                SizedBox(
                  width: available.width,
                  height: available.height,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _IPhoneFrame(media: media, child: child),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A modern iPhone drawn in Flutter: bezel, Dynamic Island, status bar,
/// side buttons and home indicator. The app inside sees the same safe areas
/// as on a real device.
class _IPhoneFrame extends StatelessWidget {
  const _IPhoneFrame({required this.media, required this.child});

  final MediaQueryData media;
  final Widget child;

  static const screen = Size(393, 852);
  static const bezel = 12.0;
  static const outerRadius = 66.0;
  static const screenRadius = 55.0;
  static const statusBar = 54.0;
  static const homeArea = 34.0;

  @override
  Widget build(BuildContext context) {
    final device = Size(screen.width + bezel * 2, screen.height + bezel * 2);

    final app = MediaQuery(
      data: media.copyWith(
        size: screen,
        devicePixelRatio: media.devicePixelRatio,
        padding: const EdgeInsets.only(top: statusBar, bottom: homeArea),
        viewPadding: const EdgeInsets.only(top: statusBar, bottom: homeArea),
      ),
      child: child,
    );

    return SizedBox(
      width: device.width + 8,
      height: device.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Side buttons: action + volume on the left, power on the right.
          const _SideButton(left: true, top: 168, height: 30),
          const _SideButton(left: true, top: 228, height: 62),
          const _SideButton(left: true, top: 302, height: 62),
          const _SideButton(left: false, top: 252, height: 96),
          Positioned(
            left: 4,
            top: 0,
            width: device.width,
            height: device.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(outerRadius),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A4542), Color(0xFF1E1B19), Color(0xFF3B3633)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: VastraColors.chocolate.withValues(alpha: 0.28),
                    blurRadius: 70,
                    offset: const Offset(0, 34),
                  ),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0D0C),
                    borderRadius: BorderRadius.circular(outerRadius - 2.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(bezel - 2.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(screenRadius),
                      child: SizedBox.fromSize(
                        size: screen,
                        child: Stack(
                          children: [
                            Positioned.fill(child: app),
                            const Positioned(left: 0, right: 0, top: 0, height: statusBar, child: _StatusBar()),
                            const Positioned(
                              left: 0,
                              right: 0,
                              bottom: 8,
                              child: IgnorePointer(child: Center(child: _HomeIndicator())),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.left, required this.top, required this.height});

  final bool left;
  final double top;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: top,
      child: Container(
        width: 6,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(left ? 3 : 0),
            right: Radius.circular(left ? 0 : 3),
          ),
          gradient: const LinearGradient(colors: [Color(0xFF3B3633), Color(0xFF5A544F), Color(0xFF2A2624)]),
        ),
      ),
    );
  }
}

class _StatusBar extends StatefulWidget {
  const _StatusBar();

  @override
  State<_StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<_StatusBar> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = '${_now.hour}:${_now.minute.toString().padLeft(2, '0')}';
    return ValueListenableBuilder<bool>(
      valueListenable: frameStatusBarLight,
      builder: (context, light, _) => _bar(time, light ? Colors.white : VastraColors.charcoal),
    );
  }

  Widget _bar(String time, Color ink) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Dynamic Island
          Positioned(
            top: 11,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 124,
                height: 36,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0xFF2B3A55), Color(0xFF0B0B0F)]),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 46,
            top: 18,
            child: Text(
              time,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.2),
            ),
          ),
          Positioned(
            right: 30,
            top: 20,
            child: Row(
              children: [
                _SignalBars(color: ink),
                const SizedBox(width: 6),
                Icon(Icons.wifi_rounded, size: 17, color: ink),
                const SizedBox(width: 6),
                _Battery(color: ink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in [4.0, 6.5, 9.0, 11.5])
          Container(
            width: 3,
            height: h,
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
          ),
      ],
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 12,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
            borderRadius: BorderRadius.circular(3.5),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.82,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.8)),
              ),
            ),
          ),
        ),
        Container(
          width: 1.6,
          height: 4,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.45),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(1)),
          ),
        ),
      ],
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: frameStatusBarLight,
      builder: (context, light, _) => Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: light ? Colors.white : VastraColors.charcoal,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    final url = kIsWeb ? Uri.base.origin : 'https://vastra.app';
    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VastraLogo(height: 120),
          const SizedBox(height: 14),
          Text(
            'Your closet, styled for the day — and tried on before you buy.',
            style: GoogleFonts.outfit(fontSize: 18, height: 1.5, color: VastraColors.chocolate),
          ),
          const SizedBox(height: 20),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Pip(PipPose.rampwalk, size: 150),
              SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: PipBubble('Psst — I look even cuter on your phone 💕'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          VastraSurface(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: QrImageView(
                    data: url,
                    size: 104,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: VastraColors.charcoal),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: VastraColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best on your phone',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to open, then Share → Add to Home Screen.',
                        style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: VastraColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
