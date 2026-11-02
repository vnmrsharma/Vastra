import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_controller.dart';
import '../../providers/today_controller.dart';
import '../../services/functions_api.dart';
import '../../services/wardrobe_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

/// Which part of the body a closet category dresses.
const _slotFor = {
  'tops': 'top',
  'trousers': 'bottom',
  'skirts': 'bottom',
  'dresses': 'base',
  'outerwear': 'outer',
  'shoes': 'shoes',
};
const _slotOrder = ['outer', 'top', 'base', 'bottom', 'shoes'];

const _shelves = <(String, String, List<String>)>[
  ('Tops', '👚', ['tops']),
  ('Bottoms', '👖', ['trousers', 'skirts']),
  ('Dresses', '👗', ['dresses']),
  ('Layers', '🧥', ['outerwear']),
  ('Shoes', '👟', ['shoes']),
];

/// "Dress up": you on a little stage, a closet shelf below. Mix and match pieces (or take a look
/// Pip styled) and YouCam puts the whole outfit on you, one piece at a time.
class DressUpScreen extends StatefulWidget {
  const DressUpScreen({super.key, @visibleForTesting this.debugItems});

  final List<WardrobeItem>? debugItems;

  @override
  State<DressUpScreen> createState() => _DressUpScreenState();
}

class _DressUpScreenState extends State<DressUpScreen> {
  late final _wardrobe = WardrobeService();
  final _api = const FunctionsApi();
  StreamSubscription<List<WardrobeItem>>? _itemsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _progressSub;
  static bool _portraitCutoutRequested = false;

  List<WardrobeItem> _items = [];
  bool _loaded = false;
  final Map<String, String> _slots = {};
  bool _styled = false;
  String _shelf = 'Tops';

  bool _running = false;
  String? _progress;
  bool _comparing = false;
  bool _portraitBusy = false;
  bool _wearing = false;
  ({String key, String url, String? cutout, String jobId})? _result;

  @override
  void initState() {
    super.initState();
    if (widget.debugItems != null) {
      _items = widget.debugItems!;
      _loaded = true;
      return;
    }
    final uid = context.read<AuthController>().uid;
    if (uid != null) {
      _itemsSub = _wardrobe.watch(uid).listen((items) {
        if (!mounted) return;
        _wardrobe.ensureCutouts(items);
        setState(() {
          _items = items;
          _loaded = true;
          _slots.removeWhere((_, id) => !items.any((i) => i.id == id));
        });
      }, onError: (Object _) {});
    }
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  WardrobeItem? _byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WardrobeItem> get _outfit =>
      _slotOrder.map((s) => _slots[s]).whereType<String>().map(_byId).whereType<WardrobeItem>().toList();

  String get _outfitKey => (_outfit.map((i) => i.id).toList()..sort()).join(',');

  void _toggle(WardrobeItem item) {
    final slot = _slotFor[item.category];
    if (slot == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_slots[slot] == item.id) {
        _slots.remove(slot);
        return;
      }
      _slots[slot] = item.id;
      if (slot == 'base') {
        _slots.remove('top');
        _slots.remove('bottom');
      } else if (slot == 'top' || slot == 'bottom') {
        _slots.remove('base');
      }
    });
  }

  void _wearLook(List<LookItem> pieces) {
    HapticFeedback.selectionClick();
    setState(() {
      _slots.clear();
      for (final piece in pieces) {
        final slot = _slotFor[piece.category];
        if (slot != null && _byId(piece.id) != null) _slots[slot] = piece.id;
      }
      if (_slots.containsKey('base')) {
        _slots.remove('top');
        _slots.remove('bottom');
      }
    });
  }

  /// A random complete outfit: a dress or top + bottoms, plus shoes and sometimes a layer.
  void _surprise() {
    final rnd = Random();
    List<WardrobeItem> of(List<String> cats) => _items.where((i) => cats.contains(i.category)).toList();
    WardrobeItem? pick(List<WardrobeItem> list) => list.isEmpty ? null : list[rnd.nextInt(list.length)];
    final dresses = of(['dresses']);
    final tops = of(['tops']);
    final bottoms = of(['trousers', 'skirts']);
    final useDress = dresses.isNotEmpty && (tops.isEmpty || bottoms.isEmpty || rnd.nextBool());
    final pieces = <WardrobeItem?>[
      if (useDress) pick(dresses) else ...[pick(tops), pick(bottoms)],
      pick(of(['shoes'])),
      if (rnd.nextInt(3) == 0) pick(of(['outerwear'])),
    ].whereType<WardrobeItem>();
    _wearLook(pieces.map((i) => LookItem(id: i.id, name: i.name, category: i.category)).toList());
  }

  Future<void> _addPortrait() async {
    final auth = context.read<AuthController>();
    final photos = await pickPhotos(
      context,
      title: 'Your try-on portrait',
      subtitle: 'Stand straight, face the camera, just you in the frame.',
    );
    if (photos.isEmpty || auth.uid == null) return;
    setState(() => _portraitBusy = true);
    try {
      await auth.profiles.uploadTryOnPhoto(uid: auth.uid!, photo: photos.first);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _portraitBusy = false);
    }
  }

  Future<void> _seeItOnMe() async {
    final uid = context.read<AuthController>().uid;
    final outfit = _outfit;
    if (uid == null || outfit.isEmpty || _running) return;
    final key = _outfitKey;
    HapticFeedback.mediumImpact();
    setState(() {
      _running = true;
      _progress = 'Getting you ready…';
    });
    _progressSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tryOnJobs')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
          if (!mounted || snap.docs.isEmpty) return;
          final job = TryOnJob.fromDoc(snap.docs.first.id, snap.docs.first.data());
          if (job.kind != 'outfit' || job.status != 'processing' || job.step == 0) return;
          setState(() => _progress = 'Putting on ${job.stepLabel ?? 'your piece'} · ${job.step}/${job.steps}');
        }, onError: (Object _) {});
    try {
      final result = await _api.dressUp(outfit.map((i) => i.id).toList());
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _result = (key: key, url: result.resultUrl, cutout: result.cutoutUrl, jobId: result.jobId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      await _progressSub?.cancel();
      _progressSub = null;
      if (mounted) {
        setState(() {
          _running = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _wearToday() async {
    final uid = context.read<AuthController>().uid;
    final outfit = _outfit;
    if (uid == null || outfit.isEmpty || _wearing) return;
    setState(() => _wearing = true);
    try {
      await _wardrobe.logOutfit(
        uid: uid,
        itemIds: outfit.map((i) => i.id).toList(),
        title: outfit.map((i) => i.name).join(' + '),
        occasion: context.read<TodayController>().occasion,
      );
      if (mounted) celebrateWithPip(context, message: 'Pinned for today — you look amazing ✨');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _wearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    if (profile?.tryOnPhotoPath != null && profile?.portraitCutoutUrl == null && !_portraitCutoutRequested) {
      _portraitCutoutRequested = true;
      _api.cutoutPortrait().catchError((_) {});
    }

    final outfit = _outfit;
    final showingResult = _result != null && _result!.key == _outfitKey && outfit.isNotEmpty;
    final portraitCutout = profile?.portraitCutoutUrl;
    final portrait = profile?.tryOnPhotoUrl;

    String? personUrl;
    var personIsCutout = false;
    if (_result != null && !_comparing) {
      personUrl = _result!.cutout ?? _result!.url;
      personIsCutout = _result!.cutout != null;
    } else {
      personUrl = portraitCutout ?? portrait;
      personIsCutout = portraitCutout != null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageHeight = (constraints.maxHeight * 0.53).clamp(260.0, 460.0);
        return Column(
          children: [
            SizedBox(
              height: stageHeight,
              child: _Stage(
                personUrl: personUrl,
                personIsCutout: personIsCutout,
                hasPortrait: portrait != null,
                portraitBusy: _portraitBusy,
                running: _running,
                progress: _progress,
                outfit: outfit,
                showingResult: showingResult,
                canRun: outfit.isNotEmpty && !showingResult && portrait != null,
                wearing: _wearing,
                onAddPortrait: _addPortrait,
                onRun: _seeItOnMe,
                onWear: _wearToday,
                onRemove: _toggle,
                onCompare: _result == null ? null : (v) => setState(() => _comparing = v),
              ),
            ),
            Expanded(
              child: _Sheet(
                styled: _styled,
                onMode: (v) => setState(() => _styled = v),
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? _EmptyCloset(onAdd: () => context.go('/app/closet'))
                    : _styled
                    ? _StyledLooks(items: _items, onPick: _wearLook, onSurprise: _surprise)
                    : _MixAndMatch(
                        items: _items,
                        shelf: _shelf,
                        selected: _slots.values.toSet(),
                        onShelf: (s) => setState(() => _shelf = s),
                        onToggle: _toggle,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.personUrl,
    required this.personIsCutout,
    required this.hasPortrait,
    required this.portraitBusy,
    required this.running,
    required this.progress,
    required this.outfit,
    required this.showingResult,
    required this.canRun,
    required this.wearing,
    required this.onAddPortrait,
    required this.onRun,
    required this.onWear,
    required this.onRemove,
    required this.onCompare,
  });

  final String? personUrl;
  final bool personIsCutout;
  final bool hasPortrait;
  final bool portraitBusy;
  final bool running;
  final String? progress;
  final List<WardrobeItem> outfit;
  final bool showingResult;
  final bool canRun;
  final bool wearing;
  final VoidCallback onAddPortrait;
  final VoidCallback onRun;
  final VoidCallback onWear;
  final ValueChanged<WardrobeItem> onRemove;
  final ValueChanged<bool>? onCompare;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        Widget person;
        if (!hasPortrait) {
          person = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Pip(PipPose.outfitReveal, size: 110),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: portraitBusy ? null : onAddPortrait,
                icon: portraitBusy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.photo_camera_front_rounded),
                label: const Text('Add your portrait to dress up'),
              ),
            ],
          );
        } else if (personIsCutout) {
          person = SizedBox(
            width: c.maxWidth * 0.62,
            height: c.maxHeight * 0.9,
            child: Image.network(
              personUrl!,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              frameBuilder: (context, child, frame, sync) =>
                  AnimatedOpacity(opacity: sync || frame != null ? 1 : 0, duration: 350.ms, child: child),
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          );
        } else {
          person = Container(
            height: c.maxHeight * 0.82,
            width: c.maxHeight * 0.82 * 0.68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: VastraColors.softWhite, width: 4),
              boxShadow: [
                BoxShadow(
                  color: VastraColors.chocolate.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: VastraImage(personUrl, radius: 22),
          );
        }

        return Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: Container(
                  width: c.maxWidth * 0.5,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: RadialGradient(
                      colors: [
                        VastraColors.chocolate.withValues(alpha: 0.18),
                        VastraColors.chocolate.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: hasPortrait ? Alignment.bottomCenter : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(bottom: personIsCutout ? 12 : 22),
                  child: GestureDetector(
                    onLongPressStart: onCompare == null ? null : (_) => onCompare!(true),
                    onLongPressEnd: onCompare == null ? null : (_) => onCompare!(false),
                    child: AnimatedSwitcher(
                      duration: 450.ms,
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
                      ),
                      child: KeyedSubtree(key: ValueKey(personUrl), child: person),
                    ),
                  ),
                ),
              ),
            ),
            if (running)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: VastraColors.softWhite.withValues(alpha: 0.08))
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1500.ms, color: VastraColors.softWhite.withValues(alpha: 0.5)),
                ),
              ),
            Positioned(
              right: 12,
              top: 12,
              bottom: 64,
              child: _OutfitRail(outfit: outfit, onRemove: running ? null : onRemove),
            ),
            Positioned(
              left: 4,
              bottom: 2,
              child: Pip(
                running ? PipPose.waiting : (showingResult ? PipPose.lovingIt : PipPose.letsStyle),
                size: 74,
                quips: const [
                  'Mix it, match it, twirl in it 💃',
                  'Hold the photo to peek at the before!',
                  'Odd combos are how icons are made.',
                ],
              ),
            ),
            if (running && progress != null)
              Positioned(
                top: 12,
                left: 12,
                right: 70,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StagePill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            progress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: VastraColors.charcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(),
              ),
            Positioned(
              left: 84,
              right: 70,
              bottom: 14,
              child: Center(
                child: AnimatedSwitcher(
                  duration: 250.ms,
                  child: canRun && !running
                      ? FilledButton.icon(
                          key: const ValueKey('run'),
                          onPressed: onRun,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('See it on me'),
                        ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack)
                      : showingResult && !running
                      ? FilledButton.tonalIcon(
                          key: const ValueKey('wear'),
                          onPressed: wearing ? null : onWear,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Wear today'),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Warm fitting-room backdrop: blush glow with soft arches (Vastra's take on a photo booth).
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6E3DE), Color(0xFFF8EEE6), VastraColors.ivory],
        ),
      ),
      child: CustomPaint(painter: _ArchesPainter()),
    );
  }
}

class _ArchesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final floor = size.height - 18;
    for (var i = 0; i < 4; i++) {
      final w = size.width * (0.42 + i * 0.17);
      final h = size.height * (0.78 + i * 0.1);
      final rect = Rect.fromLTWH(cx - w / 2, floor - h, w, h + 40);
      final rrect = RRect.fromRectAndCorners(rect, topLeft: Radius.circular(w / 2), topRight: Radius.circular(w / 2));
      final alpha = 0.22 - i * 0.045;
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = VastraColors.burgundySoft.withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = VastraColors.burgundySoft.withValues(alpha: alpha),
      );
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [VastraColors.softWhite.withValues(alpha: 0.85), VastraColors.softWhite.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, size.height * 0.55), radius: size.width * 0.38));
    canvas.drawCircle(Offset(cx, size.height * 0.55), size.width * 0.38, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: VastraColors.softWhite.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(99),
      boxShadow: [BoxShadow(color: VastraColors.chocolate.withValues(alpha: 0.1), blurRadius: 12)],
    ),
    child: child,
  );
}

/// The pieces you've picked, stacked like a little outfit card on the side of the stage.
class _OutfitRail extends StatelessWidget {
  const _OutfitRail({required this.outfit, required this.onRemove});

  final List<WardrobeItem> outfit;
  final ValueChanged<WardrobeItem>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (outfit.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final item in outfit)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  TapTarget(
                        onTap: onRemove == null ? null : () => onRemove!(item),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: VastraColors.softWhite,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: VastraColors.chocolate.withValues(alpha: 0.12), blurRadius: 10),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: GarmentImage(
                                imageUrl: item.imageUrl,
                                cutoutUrl: item.tileCutoutUrl,
                                radius: 13,
                                padding: const EdgeInsets.all(3),
                              ),
                            ),
                            if (onRemove != null)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(color: VastraColors.charcoal, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 12, color: VastraColors.softWhite),
                                ),
                              ),
                          ],
                        ),
                      )
                      .animate(key: ValueKey(item.id))
                      .fadeIn()
                      .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),
            ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.styled, required this.onMode, required this.child});

  final bool styled;
  final ValueChanged<bool> onMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VastraColors.softWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: VastraColors.chocolate.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: VastraColors.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Try a new look',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                  ),
                ),
                _ModeChip(label: 'Mix & match', selected: !styled, onTap: () => onMode(false)),
                const SizedBox(width: 6),
                _ModeChip(label: 'Styled', selected: styled, onTap: () => onMode(true)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? VastraColors.burgundy : VastraColors.ivoryDeep,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? VastraColors.softWhite : VastraColors.chocolate,
          ),
        ),
      ),
    );
  }
}

class _MixAndMatch extends StatelessWidget {
  const _MixAndMatch({
    required this.items,
    required this.shelf,
    required this.selected,
    required this.onShelf,
    required this.onToggle,
  });

  final List<WardrobeItem> items;
  final String shelf;
  final Set<String> selected;
  final ValueChanged<String> onShelf;
  final ValueChanged<WardrobeItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final shelves = _shelves.where((s) => items.any((i) => s.$3.contains(i.category))).toList();
    final current = shelves.firstWhere(
      (s) => s.$1 == shelf,
      orElse: () => shelves.isEmpty ? _shelves.first : shelves.first,
    );
    final shown = items.where((i) => current.$3.contains(i.category)).toList();

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final s in shelves)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: ChipEmoji(s.$2),
                      label: Text(s.$1),
                      selected: s.$1 == current.$1,
                      onSelected: (_) => onShelf(s.$1),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'Snap some tops, bottoms or shoes to mix and match.',
                    style: GoogleFonts.outfit(color: VastraColors.muted),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _PieceTile(
                    item: shown[i],
                    selected: selected.contains(shown[i].id),
                    onTap: () => onToggle(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.item, required this.selected, required this.onTap});

  final WardrobeItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 180.ms,
          decoration: BoxDecoration(
            color: VastraColors.tile,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? VastraColors.burgundy : Colors.transparent, width: 2.2),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GarmentImage(
                imageUrl: item.imageUrl,
                cutoutUrl: item.tileCutoutUrl,
                radius: 16,
                padding: const EdgeInsets.all(10),
              ),
              if (item.cutoutUrl == null && item.cutoutStatus == 'processing')
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: VastraColors.softWhite.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('✂️ tidying', style: GoogleFonts.outfit(fontSize: 10, color: VastraColors.chocolate)),
                  ),
                ),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: VastraColors.burgundy, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 15, color: VastraColors.softWhite),
                  ).animate().scale(curve: Curves.easeOutBack),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ready-made outfits: Pip's looks for today plus a "Surprise me" shuffle.
class _StyledLooks extends StatelessWidget {
  const _StyledLooks({required this.items, required this.onPick, required this.onSurprise});

  final List<WardrobeItem> items;
  final ValueChanged<List<LookItem>> onPick;
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayController>();
    final looks = today.current?.suggestions ?? const <OutfitSuggestion>[];
    if (today.current == null && !today.loading && today.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => today.load());
    }
    final byId = {for (final i in items) i.id: i};

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: looks.length + 1 + (today.loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _LookTile(
            title: 'Surprise me',
            subtitle: 'A random combo from your closet',
            onTap: onSurprise,
            child: const Center(child: Text('🎲', style: TextStyle(fontSize: 44))),
          );
        }
        if (i > looks.length) {
          return Container(
            decoration: BoxDecoration(color: VastraColors.tile, borderRadius: BorderRadius.circular(18)),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms);
        }
        final look = looks[i - 1];
        final pieces = look.items.take(4).toList();
        return _LookTile(
          title: look.title,
          subtitle: '${occasionIcons[today.occasion] ?? ''} ${occasionLabel(today.occasion)}',
          onTap: () => onPick(look.items),
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(6),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final p in pieces)
                GarmentImage(
                  imageUrl: p.imageUrl,
                  cutoutUrl: p.tileCutoutUrl ?? byId[p.id]?.tileCutoutUrl,
                  radius: 10,
                  padding: const EdgeInsets.all(3),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LookTile extends StatelessWidget {
  const _LookTile({required this.title, required this.subtitle, required this.child, required this.onTap});

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: VastraColors.tile, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 11, color: VastraColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCloset extends StatelessWidget {
  const _EmptyCloset({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your shelf is empty — snap a few pieces and come play dress up!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: VastraColors.chocolate),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Snap clothes'),
            ),
          ],
        ),
      ),
    );
  }
}
