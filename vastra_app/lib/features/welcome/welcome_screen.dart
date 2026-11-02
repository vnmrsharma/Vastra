import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/vastra_colors.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _features = [
    (Icons.checkroom_rounded, 'Snap your closet — I’ll sort it'),
    (Icons.wb_sunny_rounded, 'Looks for today’s weather & plans'),
    (Icons.auto_awesome_rounded, 'Try anything on with YouCam'),
  ];

  @override
  Widget build(BuildContext context) {
    return VastraPage(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: VastraLogo(height: 64))
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: -0.1, end: 0),
                  const Spacer(),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Pip(PipPose.happy, size: 190),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 70),
                          child: const PipBubble('Hi! I’m Pip — I hold outfits together. Let’s style your days ✨')
                              .animate()
                              .fadeIn(delay: 450.ms, duration: 350.ms)
                              .slideX(begin: -0.08, end: 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Find the look. Shop your wardrobe.\nTry what’s missing.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: VastraColors.charcoal,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  const SizedBox(height: 18),
                  for (var i = 0; i < _features.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FeatureRow(icon: _features[i].$1, label: _features[i].$2),
                    ).animate().fadeIn(delay: (300 + i * 90).ms).slideX(begin: 0.05, end: 0),
                  const Spacer(),
                  const SizedBox(height: 22),
                  VastraPrimaryButton(label: 'Start styling', onPressed: () => context.go('/signup')),
                  const SizedBox(height: 10),
                  VastraSecondaryButton(label: 'I already have an account', onPressed: () => context.go('/login')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return VastraSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: VastraColors.blush, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: VastraColors.burgundy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(color: VastraColors.charcoal, fontWeight: FontWeight.w500, fontSize: 14.5),
            ),
          ),
        ],
      ),
    );
  }
}
