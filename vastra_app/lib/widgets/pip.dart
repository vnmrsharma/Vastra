import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/vastra_colors.dart';

/// Pip — Vastra's safety-pin mascot. She holds every outfit together.
enum PipPose {
  happy,
  cheeky,
  cheerful,
  curious,
  excited,
  searching,
  thoughtful,
  celebration,
  rampwalk,
  letsStyle,
  lovingIt,
  outfitReveal,
  waiting;

  String get asset =>
      'assets/pip/${switch (this) {
        PipPose.letsStyle => 'lets_style',
        PipPose.lovingIt => 'loving_it',
        PipPose.outfitReveal => 'outfit_reveal',
        _ => name,
      }}.png';

  PipMotion get defaultMotion => switch (this) {
    PipPose.excited || PipPose.celebration => PipMotion.bounce,
    PipPose.rampwalk || PipPose.cheeky => PipMotion.strut,
    _ => PipMotion.float,
  };
}

/// Illustrated scenes of Pip in her world (kept with their backgrounds).
enum PipScene {
  catwalk,
  wardrobe,
  arranging,
  changing,
  relaxing,
  cafe;

  String get asset => 'assets/pip/scenes/$name.jpg';
}

enum PipMotion { float, bounce, strut, still }

const pipQuips = [
  'I hold everything together. Literally. 📍',
  'Pinned it! 💕',
  'Stop it, you’re making me blush.',
  'Outfit of the day? Say less.',
  'I’m sharp — but only about fashion.',
  'Every great look needs a little pinning.',
  'Feeling cute today? Same.',
  'Tap me again, I dare you 😎',
  'Red sneakers go with everything. Trust me.',
  'Your closet called. It misses you.',
];

/// Precaches every Pip asset so she never pops in blank.
Future<void> precachePip(BuildContext context) async {
  final futures = <Future<void>>[
    for (final pose in PipPose.values) precacheImage(AssetImage(pose.asset), context),
    for (final scene in PipScene.values) precacheImage(AssetImage(scene.asset), context),
    precacheImage(const AssetImage(VastraLogo.asset), context),
  ];
  await Future.wait(futures.map((f) => f.catchError((_) {})));
}

/// Animated Pip. Floats/bounces/struts on her own; tap her for a wiggle and a quip.
class Pip extends StatefulWidget {
  const Pip(
    this.pose, {
    super.key,
    this.size = 140,
    this.motion,
    this.interactive = true,
    this.quips = pipQuips,
    this.popIn = true,
  });

  final PipPose pose;
  final double size;
  final PipMotion? motion;
  final bool interactive;
  final List<String> quips;
  final bool popIn;

  @override
  State<Pip> createState() => _PipState();
}

class _PipState extends State<Pip> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2200 + math.Random().nextInt(600)),
  )..repeat(reverse: true);
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  String? _quip;
  Timer? _quipTimer;
  int _quipIndex = math.Random().nextInt(pipQuips.length);
  final _portal = OverlayPortalController();
  final _pipKey = GlobalKey();

  PipMotion get _motion => widget.motion ?? widget.pose.defaultMotion;

  @override
  void dispose() {
    _idle.dispose();
    _wiggle.dispose();
    _quipTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _wiggle.forward(from: 0);
    if (widget.quips.isEmpty) return;
    setState(() {
      _quipIndex = (_quipIndex + 1) % widget.quips.length;
      _quip = widget.quips[_quipIndex];
    });
    _portal.show();
    _quipTimer?.cancel();
    _quipTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      _portal.hide();
      setState(() => _quip = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(anim), child: child),
      ),
      child: Image.asset(
        widget.pose.asset,
        key: ValueKey(widget.pose),
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );

    Widget pip = AnimatedBuilder(
      animation: Listenable.merge([_idle, _wiggle]),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_idle.value);
        final w = _wiggle.value;
        final wiggle = math.sin(w * math.pi * 6) * (1 - w) * 0.16;
        double dy = 0, angle = 0, scale = 1;
        switch (_motion) {
          case PipMotion.float:
            dy = -6 * t;
            angle = (t - 0.5) * 0.05;
          case PipMotion.bounce:
            dy = -12 * math.sin(t * math.pi);
            scale = 1 + 0.03 * math.sin(t * math.pi);
          case PipMotion.strut:
            dy = -4 * math.sin(t * math.pi * 2).abs();
            angle = (t - 0.5) * 0.12;
          case PipMotion.still:
            break;
        }
        if (w > 0) scale += 0.06 * math.sin(w * math.pi);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angle + wiggle,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
          ),
        );
      },
      child: image,
    );

    if (widget.popIn) {
      pip = pip
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(
            begin: const Offset(0.7, 0.7),
            end: const Offset(1, 1),
            duration: 650.ms,
            curve: Curves.elasticOut,
            alignment: Alignment.bottomCenter,
          );
    }

    if (!widget.interactive) return pip;

    return Semantics(
      label: 'Pip, your style sidekick',
      button: true,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildQuip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: KeyedSubtree(key: _pipKey, child: pip),
        ),
      ),
    );
  }

  /// The quip floats on the overlay, placed from Pip's on-screen position and
  /// kept fully inside the visible screen (clear of the status bar and edges).
  Widget _buildQuip(BuildContext context) {
    final quip = _quip;
    final pipBox = _pipKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (quip == null || pipBox == null || overlayBox == null || !pipBox.attached) {
      return const SizedBox.shrink();
    }
    final topLeft = overlayBox.globalToLocal(pipBox.localToGlobal(Offset.zero));
    final anchor = topLeft & pipBox.size;
    // The overlay may sit above (or below) whatever applies the status-bar inset, so honour either.
    final topInset = math.max(MediaQuery.paddingOf(context).top, MediaQuery.paddingOf(this.context).top);

    return IgnorePointer(
      child: CustomSingleChildLayout(
        delegate: _QuipLayout(anchor: anchor, topInset: topInset),
        child: PipBubble(quip, maxWidth: 240, tail: BubbleTail.none)
            .animate(key: ValueKey(quip))
            .fadeIn(duration: 180.ms)
            .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
      ),
    );
  }
}

class _QuipLayout extends SingleChildLayoutDelegate {
  _QuipLayout({required this.anchor, required this.topInset});

  final Rect anchor;
  final double topInset;
  static const _margin = 12.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(math.max(0, constraints.maxWidth - _margin * 2), constraints.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final minX = _margin;
    final maxX = math.max(minX, size.width - child.width - _margin);
    final x = (anchor.center.dx - child.width / 2).clamp(minX, maxX);

    final minY = topInset + 6;
    var y = anchor.top - child.height - 4;
    if (y < minY) {
      // No room above Pip: show the bubble beside/below her head instead.
      y = math.min(anchor.top + anchor.height * 0.15, size.height - child.height - _margin);
      y = math.max(y, minY);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_QuipLayout old) => old.anchor != anchor || old.topInset != topInset;
}

enum BubbleTail { left, bottom, none }

/// Pip's speech bubble.
class PipBubble extends StatelessWidget {
  const PipBubble(this.text, {super.key, this.maxWidth = 260, this.tail = BubbleTail.left, this.emphasis = false});

  final String text;
  final double maxWidth;
  final BubbleTail tail;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: emphasis ? VastraColors.burgundy : VastraColors.softWhite,
        borderRadius: BorderRadius.circular(18),
        border: emphasis ? null : Border.all(color: VastraColors.border),
        boxShadow: [
          BoxShadow(color: VastraColors.chocolate.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: emphasis ? VastraColors.softWhite : VastraColors.charcoal,
        ),
      ),
    );
    if (tail == BubbleTail.none) return bubble;

    final tailColor = emphasis ? VastraColors.burgundy : VastraColors.softWhite;
    if (tail == BubbleTail.bottom) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble,
          CustomPaint(size: const Size(16, 9), painter: _TailPainter(tailColor, down: true)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(size: const Size(9, 16), painter: _TailPainter(tailColor, down: false)),
        Flexible(child: bubble),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color, {required this.down});
  final Color color;
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (down) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color || old.down != down;
}

/// Pip with a speech bubble beside her — the app's voice.
class PipSays extends StatelessWidget {
  const PipSays(this.pose, this.message, {super.key, this.size = 92, this.emphasis = false});

  final PipPose pose;
  final String message;
  final double size;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Pip(pose, size: size),
        const SizedBox(width: 6),
        Flexible(
          child: PipBubble(message, emphasis: emphasis)
              .animate(key: ValueKey(message))
              .fadeIn(delay: 180.ms, duration: 280.ms)
              .slideX(begin: -0.06, end: 0, curve: Curves.easeOut),
        ),
      ],
    );
  }
}

/// One of Pip's illustrated scenes as a soft rounded card.
class PipSceneCard extends StatelessWidget {
  const PipSceneCard(this.scene, {super.key, this.height = 180, this.caption});

  final PipScene scene;
  final double height;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(scene.asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 6.seconds,
                  curve: Curves.easeInOut,
                ),
            if (caption != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: PipBubble(caption!, tail: BubbleTail.none, maxWidth: 280),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Pip + Vastra wordmark.
class VastraLogo extends StatelessWidget {
  const VastraLogo({super.key, this.height = 56});

  static const asset = 'assets/brand/logo.png';
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vastra',
      image: true,
      child: Image.asset(asset, height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
  }
}

/// Full-screen celebration: confetti + a bouncing Pip with a message.
Future<void> celebrateWithPip(
  BuildContext context, {
  required String message,
  PipPose pose = PipPose.celebration,
}) async {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(pose: pose, message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.pose, required this.message, required this.onDone});

  final PipPose pose;
  final String message;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..forward().whenComplete(() => widget.onDone());
  final _particles = List.generate(46, (_) => _Particle.random());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2);
          return Opacity(
            opacity: fade.clamp(0, 1),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: VastraColors.ivory.withValues(alpha: 0.55 * fade)),
                ),
                Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(_particles, t))),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Pip(widget.pose, size: 190, interactive: false, motion: PipMotion.bounce),
                      const SizedBox(height: 8),
                      PipBubble(widget.message, tail: BubbleTail.none, emphasis: true, maxWidth: 260),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle(this.x, this.speed, this.drift, this.spin, this.color, this.size, this.delay);

  factory _Particle.random() {
    final r = math.Random();
    const colors = [VastraColors.burgundy, VastraColors.blush, Color(0xFFE9C85A), VastraColors.mint, Color(0xFFE05468)];
    return _Particle(
      r.nextDouble(),
      0.7 + r.nextDouble() * 0.6,
      (r.nextDouble() - 0.5) * 0.3,
      r.nextDouble() * 8,
      colors[r.nextInt(colors.length)],
      5 + r.nextDouble() * 7,
      r.nextDouble() * 0.25,
    );
  }

  final double x, speed, drift, spin, size, delay;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = (p.x + p.drift * local) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2),
        ),
        Paint()..color = p.color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
