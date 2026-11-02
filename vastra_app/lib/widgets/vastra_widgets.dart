import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/vastra_colors.dart';
import 'pip.dart';

/// Warm gradient with soft colour blobs, shared by every screen.
class VastraBackdrop extends StatelessWidget {
  const VastraBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF4E9DC), VastraColors.ivory, Color(0xFFF3E4E0)],
                ),
              ),
            ),
          ),
          const _Blob(top: -80, left: -60, size: 260, color: Color(0xFFF2DCCB)),
          const _Blob(top: 120, right: -90, size: 240, color: Color(0xFFF1D6D3)),
          const _Blob(bottom: -100, left: 20, size: 280, color: Color(0xFFE3EDE4)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({this.top, this.left, this.right, this.bottom, required this.size, required this.color});

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Every full-screen route goes through this so text, inputs and sheets
/// always have a Material ancestor and the same warm backdrop.
class VastraPage extends StatelessWidget {
  const VastraPage({super.key, required this.child, this.appBar, this.bottomNavigationBar, this.safeArea = true});

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(bottom: bottomNavigationBar == null, child: child) : child;
    return Scaffold(
      backgroundColor: VastraColors.ivory,
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned.fill(child: VastraBackdrop()),
          Positioned.fill(child: content),
        ],
      ),
    );
  }
}

class VastraSurface extends StatelessWidget {
  const VastraSurface({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.margin});

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: VastraColors.softWhite.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VastraColors.border),
        boxShadow: [
          BoxShadow(color: VastraColors.chocolate.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

class VastraPill extends StatelessWidget {
  const VastraPill(this.label, {super.key, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color ?? VastraColors.ivoryDeep, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          letterSpacing: 0.3,
          color: textColor ?? VastraColors.chocolate,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class VastraHeading extends StatelessWidget {
  const VastraHeading(this.title, {super.key, this.subtitle, this.pill, this.size = 34});

  final String title;
  final String? subtitle;
  final String? pill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pill != null) ...[VastraPill(pill!), const SizedBox(height: 12)],
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: size,
            height: 1.05,
            fontWeight: FontWeight.w600,
            color: VastraColors.charcoal,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: GoogleFonts.outfit(fontSize: 15, height: 1.45, color: VastraColors.muted)),
        ],
      ],
    );
  }
}

class VastraPrimaryButton extends StatelessWidget {
  const VastraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.expanded = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: VastraColors.softWhite),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = FilledButton(onPressed: busy ? null : onPressed, child: child);
    return expanded ? SizedBox(width: double.infinity, height: 52, child: button) : button;
  }
}

class VastraSecondaryButton extends StatelessWidget {
  const VastraSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, height: 52, child: button) : button;
  }
}

class VastraImage extends StatelessWidget {
  const VastraImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius = 0});

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: VastraColors.ivoryDeep,
      alignment: Alignment.center,
      child: const Icon(Icons.checkroom_rounded, color: VastraColors.muted),
    );

    final image = (url == null || url!.isEmpty)
        ? placeholder
        : Image.network(
            url!,
            fit: fit,
            gaplessPlayback: true,
            width: width,
            height: height,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(width: width, height: height, color: VastraColors.ivoryDeep)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1200.ms, color: VastraColors.softWhite.withValues(alpha: 0.6));
            },
            errorBuilder: (context, error, stack) => placeholder,
          );

    return radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: image) : image;
  }
}

/// A plain tap area that screen readers (and keyboard users) recognise as a button.
class TapTarget extends StatelessWidget {
  const TapTarget({super.key, required this.onTap, required this.child, this.label, this.behavior});

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final HitTestBehavior? behavior;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    container: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    child: GestureDetector(onTap: onTap, behavior: behavior, excludeFromSemantics: true, child: child),
  );
}

/// An emoji in a chip's avatar slot. Kept out of the label because the web renderer can measure emoji
/// narrower than it draws them, which clips the end of the label.
class ChipEmoji extends StatelessWidget {
  const ChipEmoji(this.emoji, {super.key});

  final String emoji;

  @override
  Widget build(BuildContext context) => Center(child: Text(emoji, style: const TextStyle(fontSize: 14, height: 1)));
}

/// A closet piece: the background-free cutout on a soft tile when YouCam has made one,
/// otherwise the original photo.
class GarmentImage extends StatelessWidget {
  const GarmentImage({
    super.key,
    required this.imageUrl,
    this.cutoutUrl,
    this.width,
    this.height,
    this.radius = 0,
    this.padding = const EdgeInsets.all(8),
  });

  final String? imageUrl;
  final String? cutoutUrl;
  final double? width;
  final double? height;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (cutoutUrl == null) return VastraImage(imageUrl, width: width, height: height, radius: radius);
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(color: VastraColors.tile, borderRadius: BorderRadius.circular(radius)),
      child: VastraImage(cutoutUrl, fit: BoxFit.contain),
    );
  }
}

class VastraEmptyState extends StatelessWidget {
  const VastraEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.emoji = '✧',
    this.action,
    this.pip,
    this.scene,
  });

  final String title;
  final String description;
  final String emoji;
  final Widget? action;
  final PipPose? pip;
  final PipScene? scene;

  @override
  Widget build(BuildContext context) {
    return VastraSurface(
      padding: EdgeInsets.fromLTRB(20, scene != null ? 14 : 24, 20, 24),
      child: Column(
        children: [
          if (scene != null)
            PipSceneCard(scene!, height: 190)
          else if (pip != null)
            Pip(pip!, size: 132)
          else
            Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: VastraColors.blush.withValues(alpha: 0.8), shape: BoxShape.circle),
                  child: Text(emoji, style: const TextStyle(fontSize: 24, color: VastraColors.burgundy)),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -5, duration: 1800.ms, curve: Curves.easeInOut),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: VastraColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: VastraColors.muted, height: 1.45),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class VastraMessage extends StatelessWidget {
  const VastraMessage(this.text, {super.key, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? VastraColors.danger : VastraColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? VastraColors.danger.withValues(alpha: 0.08) : VastraColors.mint.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GoogleFonts.outfit(color: color, fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == index;
        final done = i < index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active || done ? VastraColors.burgundy.withValues(alpha: done ? 0.45 : 1) : VastraColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

String friendlyError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '');
  if (text.contains('invalid-credential') || text.contains('wrong-password')) {
    return 'That email and password don’t match. Try again?';
  }
  if (text.contains('email-already-in-use')) {
    return 'An account already exists for this email — try signing in.';
  }
  if (text.contains('network')) {
    return 'Connection hiccup — check your internet and retry.';
  }
  return text;
}
