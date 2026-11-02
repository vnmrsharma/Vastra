import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_controller.dart';
import '../recreate/recreate_screen.dart';
import '../../providers/today_controller.dart';
import '../../providers/try_on_request.dart';
import '../../services/wardrobe_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _wardrobe = WardrobeService();
  Stream<WornToday?>? _wornStream;
  Stream<List<WardrobeItem>>? _itemsStream;
  bool _logging = false;

  Future<void> _wear(OutfitSuggestion look) async {
    final uid = context.read<AuthController>().uid;
    if (uid == null || _logging) return;
    setState(() => _logging = true);
    HapticFeedback.mediumImpact();
    try {
      await _wardrobe.logOutfit(
        uid: uid,
        itemIds: look.items.map((i) => i.id).toList(),
        title: look.title,
        occasion: context.read<TodayController>().occasion,
      );
      if (mounted) {
        celebrateWithPip(context, message: 'Pinned for today! “${look.title}” looks gorgeous on you ✨');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthController>().uid;
    if (uid != null) {
      _wornStream = _wardrobe.watchToday(uid);
      _itemsStream = _wardrobe.watch(uid);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final today = context.read<TodayController>();
      today.bindUser(auth.uid, defaultOccasion: auth.profile?.occasions.firstOrNull);
      today.load();
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final today = context.watch<TodayController>();
    final result = today.current;
    if (result == null && !today.loading && today.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => today.load());
    }
    final favourites = profile?.occasions ?? const [];
    final orderedOccasions = [...favourites, ...occasions.where((o) => !favourites.contains(o))];

    return RefreshIndicator(
      color: VastraColors.burgundy,
      onRefresh: () => today.load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('$_greeting,', style: GoogleFonts.outfit(fontSize: 15, color: VastraColors.muted)),
          Row(
            children: [
              Expanded(
                child: Text(
                  profile?.firstName ?? '',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 42,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: VastraColors.charcoal,
                  ),
                ),
              ),
              if (result?.weather != null) _WeatherPill(weather: result!.weather!),
            ],
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 10),
          _PipLine(result: result, loading: today.loading, error: today.error, occasion: today.occasion),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: orderedOccasions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final o = orderedOccasions[i];
                return ChoiceChip(
                  avatar: ChipEmoji(occasionIcons[o] ?? ''),
                  label: Text(occasionLabel(o)),
                  selected: today.occasion == o,
                  onSelected: (_) => today.selectOccasion(o),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<WornToday?>(
            stream: _wornStream,
            builder: (context, wornSnap) {
              final worn = wornSnap.data;
              if (worn == null) return const SizedBox.shrink();
              return StreamBuilder<List<WardrobeItem>>(
                stream: _itemsStream,
                builder: (context, itemsSnap) {
                  final byId = {for (final i in itemsSnap.data ?? const <WardrobeItem>[]) i.id: i};
                  final pieces = worn.itemIds.map((id) => byId[id]).whereType<WardrobeItem>().toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _WearingToday(
                      worn: worn,
                      pieces: pieces,
                      onChange: () {
                        final uid = context.read<AuthController>().uid;
                        if (uid != null) _wardrobe.clearToday(uid);
                      },
                    ).animate().fadeIn(duration: 300.ms),
                  );
                },
              );
            },
          ),
          if (profile?.tryOnPhotoUrl == null) ...[
            _Nudge(
              pip: PipPose.outfitReveal,
              title: 'Add your try-on portrait',
              body: 'One photo and you can try any piece on.',
              onTap: () => context.go('/onboarding'),
            ),
            const SizedBox(height: 14),
          ],
          if (today.loading && result == null)
            ...List.generate(2, (i) => const _LookSkeleton())
          else if (today.error != null && result == null)
            VastraEmptyState(
              pip: PipPose.thoughtful,
              title: 'Couldn’t style you just now',
              description: today.error!,
              action: FilledButton(onPressed: () => today.load(force: true), child: const Text('Try again')),
            )
          else if (result != null && result.suggestions.isEmpty)
            VastraEmptyState(
              scene: PipScene.wardrobe,
              title: 'Let’s fill your closet',
              description: result.note ?? 'Add a few more pieces and I’ll put outfits together for you.',
              action: FilledButton.icon(
                onPressed: () => context.go('/app/closet'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add pieces'),
              ),
            )
          else if (result != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Today’s looks',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: VastraColors.charcoal,
                    ),
                  ),
                ),
                if (today.loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    tooltip: 'New ideas',
                    onPressed: () => today.load(force: true),
                    icon: const Icon(Icons.refresh_rounded, color: VastraColors.chocolate),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < result.suggestions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _LookCard(
                  index: i,
                  look: result.suggestions[i],
                  onWear: _logging ? null : () => _wear(result.suggestions[i]),
                ).animate().fadeIn(delay: (i * 90).ms).slideY(begin: 0.05, end: 0),
              ),
          ],
          const SizedBox(height: 4),
          const RecreateNudge(),
        ],
      ),
    );
  }
}

class _WeatherPill extends StatelessWidget {
  const _WeatherPill({required this.weather});

  final WeatherSnapshot weather;

  String get _emoji {
    final d = weather.description.toLowerCase();
    if (d.contains('rain') || d.contains('drizzle') || d.contains('shower')) return '🌧';
    if (d.contains('snow')) return '❄️';
    if (d.contains('cloud') || d.contains('overcast') || d.contains('mist') || d.contains('fog')) return '☁️';
    return '☀️';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VastraColors.mint.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$_emoji ${weather.temperatureC.round()}°',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.success),
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.pip, required this.title, required this.body, required this.onTap});

  final PipPose pip;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VastraColors.blush.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(
            children: [
              Pip(pip, size: 64, interactive: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                    ),
                    Text(body, style: GoogleFonts.outfit(fontSize: 13, color: VastraColors.chocolate)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: VastraColors.burgundy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pip's running commentary on the day: weather, time and what you're dressing for.
class _PipLine extends StatelessWidget {
  const _PipLine({required this.result, required this.loading, required this.error, required this.occasion});

  final TodayResult? result;
  final bool loading;
  final String? error;
  final String occasion;

  (PipPose, String) get _line {
    final hour = DateTime.now().hour;
    final timePose = hour < 12
        ? PipPose.happy
        : hour < 18
        ? PipPose.cheerful
        : PipPose.cheeky;
    final what = occasionLabel(occasion).toLowerCase();
    if (loading && result == null) {
      return (PipPose.searching, 'Give me a sec — I’m digging through your closet for $what looks…');
    }
    if (error != null && result == null) {
      return (PipPose.thoughtful, 'Hmm, something got tangled. Pull down and I’ll try again.');
    }
    final w = result?.weather;
    if (w == null) return (timePose, 'What are we dressing for today? Pick a vibe and I’ll pin it together.');
    final t = w.temperatureC.round();
    final d = w.description.toLowerCase();
    if (d.contains('rain') || d.contains('drizzle') || d.contains('shower') || w.precipMm > 0) {
      return (PipPose.thoughtful, 'It’s $t° and wet out — cosy layers and a brolly today ☔');
    }
    if (t <= 8) return (timePose, 'Brr, $t°! Layers are our best friends today 🧣');
    if (t >= 22) return (PipPose.cheeky, 'Sunny and $t° — light, breezy and a little bit fabulous 😎');
    return (timePose, '$t° and $d — perfect for a $what look. Here’s what I’d wear!');
  }

  @override
  Widget build(BuildContext context) {
    final (pose, text) = _line;
    return PipSays(pose, text, size: 86);
  }
}

class _WearingToday extends StatelessWidget {
  const _WearingToday({required this.worn, required this.pieces, required this.onChange});

  final WornToday worn;
  final List<WardrobeItem> pieces;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [VastraColors.mint, Color(0xFFEFF4EC)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: VastraColors.success, size: 18),
              const SizedBox(width: 6),
              Text(
                'Today you’re wearing',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: VastraColors.success),
              ),
              const Spacer(),
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Change'),
              ),
            ],
          ),
          Text(
            worn.title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: VastraColors.charcoal,
            ),
          ),
          if (pieces.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pieces.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => SizedBox(
                  width: 52,
                  child: GarmentImage(
                    imageUrl: pieces[i].imageUrl,
                    cutoutUrl: pieces[i].tileCutoutUrl,
                    radius: 12,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({required this.index, required this.look, this.onWear});

  final int index;
  final OutfitSuggestion look;
  final VoidCallback? onWear;

  LookItem get _hero {
    for (final category in ['dresses', 'tops', 'outerwear', 'trousers', 'skirts']) {
      for (final item in look.items) {
        if (item.category == category) return item;
      }
    }
    return look.items.first;
  }

  @override
  Widget build(BuildContext context) {
    return VastraSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VastraPill('Look ${index + 1}', color: VastraColors.blush, textColor: VastraColors.burgundy),
              const Spacer(),
              Text('${look.items.length} pieces', style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            look.title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: VastraColors.charcoal,
            ),
          ),
          if (look.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(look.reason, style: GoogleFonts.outfit(color: VastraColors.chocolate, height: 1.4)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: look.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final item = look.items[i];
                return TapTarget(
                  onTap: () => openTryOn(context, item.id),
                  child: SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GarmentImage(
                            imageUrl: item.imageUrl,
                            cutoutUrl: item.tileCutoutUrl,
                            width: 96,
                            radius: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.chocolate),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: VastraSecondaryButton(label: 'Wear today', icon: Icons.check_rounded, onPressed: onWear),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VastraPrimaryButton(
                  label: 'Try on',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () => openTryOn(context, _hero.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LookSkeleton extends StatelessWidget {
  const _LookSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: VastraColors.softWhite.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VastraColors.border),
        ),
        alignment: Alignment.center,
        child: Text('Pip is styling your day…', style: GoogleFonts.outfit(color: VastraColors.muted)),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: VastraColors.blush.withValues(alpha: 0.7)),
    );
  }
}
