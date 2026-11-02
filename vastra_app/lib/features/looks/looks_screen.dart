import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_controller.dart';
import '../../services/try_on_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class LooksScreen extends StatefulWidget {
  const LooksScreen({super.key});

  @override
  State<LooksScreen> createState() => _LooksScreenState();
}

class _LooksScreenState extends State<LooksScreen> {
  final _service = TryOnService();
  Stream<List<TryOnJob>>? _stream;
  String? _streamUid;
  bool _favouritesOnly = false;

  Stream<List<TryOnJob>> _looksFor(String uid) {
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = _service.watchLooks(uid);
    }
    return _stream!;
  }

  void _open(String uid, TryOnJob look) {
    showDialog<void>(
      context: context,
      barrierColor: VastraColors.charcoal.withValues(alpha: 0.75),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(child: VastraImage(look.resultUrl, fit: BoxFit.contain, radius: 18)),
              const SizedBox(height: 12),
              Text(look.title, style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w600)),
              Text(
                DateFormat('EEEE d MMMM · HH:mm').format(DateTime.fromMillisecondsSinceEpoch(look.createdAt)),
                style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _service.delete(uid, look.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Look removed')));
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: VastraColors.danger),
                    label: const Text('Remove', style: TextStyle(color: VastraColors.danger)),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<TryOnJob>>(
      stream: _looksFor(uid),
      builder: (context, snap) {
        final all = snap.data ?? const <TryOnJob>[];
        final favouriteCount = all.where((l) => l.favourite).length;
        final looks = _favouritesOnly ? all.where((l) => l.favourite).toList() : all;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              sliver: SliverToBoxAdapter(
                child: VastraHeading(
                  'My looks',
                  subtitle: all.isEmpty
                      ? 'Every try-on lands here automatically.'
                      : '${all.length} try-on${all.length == 1 ? '' : 's'} · tap ♥ to keep your favourites',
                ),
              ),
            ),
            if (favouriteCount > 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: !_favouritesOnly,
                        onSelected: (_) => setState(() => _favouritesOnly = false),
                      ),
                      ChoiceChip(
                        label: Text('♥ Favourites ($favouriteCount)'),
                        selected: _favouritesOnly,
                        onSelected: (_) => setState(() => _favouritesOnly = true),
                      ),
                    ],
                  ),
                ),
              ),
            if (!snap.hasData)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (looks.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: VastraEmptyState(
                    pip: PipPose.waiting,
                    title: 'No looks yet',
                    description: 'Try something on and it’ll appear here — ready to revisit any time.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/app/try-on'),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Try something on'),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: looks.length,
                  itemBuilder: (context, i) {
                    final look = looks[i];
                    return TapTarget(
                      onTap: () => _open(uid, look),
                      child: Container(
                        decoration: BoxDecoration(
                          color: VastraColors.softWhite,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: VastraColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VastraImage(look.resultUrl),
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: Material(
                                      color: VastraColors.softWhite.withValues(alpha: 0.9),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _service.setFavourite(uid, look.id, !look.favourite);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: Icon(
                                            look.favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 18,
                                            color: VastraColors.burgundy,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (look.garmentImageUrl != null)
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        width: 42,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: VastraColors.softWhite, width: 2),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: VastraImage(look.garmentImageUrl),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    look.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: VastraColors.charcoal,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d MMM').format(DateTime.fromMillisecondsSinceEpoch(look.createdAt)),
                                    style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (i * 35).ms);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
