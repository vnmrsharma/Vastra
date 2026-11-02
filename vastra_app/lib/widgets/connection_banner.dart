import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/connectivity/online.dart';
import '../theme/vastra_colors.dart';

final _online = createOnlineListenable();

/// A soft pill at the top of the screen while the device is offline. The closet, looks and profile
/// keep working from the local cache, and changes sync once the connection is back.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: _online,
          builder: (context, online, _) => AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            top: online ? -80 : top + 8,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: ExcludeSemantics(
                excluding: online,
                child: Center(
                  child: Material(
                    color: VastraColors.charcoal.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(99),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 16, color: VastraColors.blush),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Offline — your closet still works, I’ll sync when you’re back',
                              style: GoogleFonts.outfit(fontSize: 12.5, color: VastraColors.softWhite),
                            ),
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
    );
  }
}
