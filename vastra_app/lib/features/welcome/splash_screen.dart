import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/vastra_colors.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VastraPage(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Pip(PipPose.happy, size: 170, interactive: false, motion: PipMotion.bounce),
            const SizedBox(height: 18),
            const VastraLogo(height: 54),
            const SizedBox(height: 10),
            Text('Pip is opening your wardrobe…', style: GoogleFonts.outfit(color: VastraColors.muted)),
          ],
        ),
      ),
    );
  }
}
