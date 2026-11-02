import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.pipPose,
    required this.pipSays,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final PipPose pipPose;
  final String pipSays;

  @override
  Widget build(BuildContext context) {
    return VastraPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 4),
              const VastraLogo(height: 34),
            ],
          ),
          const SizedBox(height: 6),
          PipSays(pipPose, pipSays, size: 112),
          const SizedBox(height: 10),
          VastraSurface(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VastraHeading(title, subtitle: subtitle, size: 32),
                const SizedBox(height: 22),
                ...children,
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
        ],
      ),
    );
  }
}
