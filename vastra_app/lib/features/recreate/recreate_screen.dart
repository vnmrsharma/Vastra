import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/picked_photo.dart';
import '../../providers/auth_controller.dart';
import '../../providers/today_controller.dart';
import '../../providers/try_on_request.dart';
import '../../services/functions_api.dart';
import '../../services/recreate_service.dart';
import '../../services/wardrobe_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

/// Entry card for "Recreate a look", shown on Today and in the closet.
class RecreateNudge extends StatelessWidget {
  const RecreateNudge({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VastraColors.mint.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/recreate'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(
            children: [
              const Pip(PipPose.searching, size: 64, interactive: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recreate a look',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                    ),
                    Text(
                      'Snap any outfit you love — I’ll rebuild it from your closet.',
                      style: GoogleFonts.outfit(fontSize: 13, color: VastraColors.chocolate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: VastraColors.success),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Recreate a look": snap or upload any outfit and Pip rebuilds it from your closet.
class RecreateScreen extends StatefulWidget {
  const RecreateScreen({super.key, this.initial});

  final RecreateResult? initial;

  @override
  State<RecreateScreen> createState() => _RecreateScreenState();
}

class _RecreateScreenState extends State<RecreateScreen> {
  final _api = FunctionsApi();
  final _wardrobe = WardrobeService();
  final _recreations = RecreateService();
  Stream<List<RecreateResult>>? _recent;

  PickedPhoto? _photo;
  RecreateResult? _result;
  bool _busy = false;
  bool _wearing = false;
  bool _openingTryOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.initial;
    final uid = context.read<AuthController>().uid;
    if (uid != null) _recent = _recreations.watchRecent(uid);
  }

  Future<void> _pick({required bool camera}) async {
    final photos = camera ? await pickFromCamera(context) : await pickFromLibrary(context);
    if (photos.isEmpty || !mounted) return;
    await _analyse(photos.first);
  }

  Future<void> _analyse(PickedPhoto photo) async {
    final uid = context.read<AuthController>().uid;
    if (uid == null) return;
    setState(() {
      _photo = photo;
      _result = null;
      _error = null;
      _busy = true;
    });
    try {
      final uploaded = await _wardrobe.uploadImage(uid: uid, photo: photo, folder: 'inspiration');
      final result = await _api.recreateLook(imagePath: uploaded.path, imageUrl: uploaded.url);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
    _photo = null;
    _result = null;
    _error = null;
  });

  Future<void> _wearToday(RecreateResult result) async {
    final uid = context.read<AuthController>().uid;
    if (uid == null || _wearing) return;
    setState(() => _wearing = true);
    HapticFeedback.mediumImpact();
    try {
      await _wardrobe.logOutfit(
        uid: uid,
        itemIds: result.matchedItems.map((i) => i.id).toList(),
        title: result.title,
        occasion: context.read<TodayController>().occasion,
      );
      if (mounted) celebrateWithPip(context, message: 'Pinned for today! Your take on “${result.title}” ✨');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _wearing = false);
    }
  }

  /// The piece that carries the look best: a dress, then a top or jacket.
  void _tryMyVersion(RecreateResult result) {
    const priority = ['dresses', 'tops', 'outerwear', 'trousers', 'skirts', 'shoes'];
    final items = [...result.matchedItems]
      ..sort((a, b) {
        int rank(LookItem i) => priority.contains(i.category) ? priority.indexOf(i.category) : priority.length;
        return rank(a).compareTo(rank(b));
      });
    if (items.isNotEmpty) openTryOn(context, items.first.id);
  }

  /// Sends the inspiration photo to YouCam so the whole look goes on the user's portrait.
  Future<void> _tryOriginal(RecreateResult result) async {
    if (_openingTryOn) return;
    var photo = _photo;
    if (photo == null) {
      if (result.imagePath == null) return;
      setState(() => _openingTryOn = true);
      try {
        final bytes = await FirebaseStorage.instance.ref(result.imagePath!).getData(10 * 1024 * 1024);
        if (bytes != null) photo = PickedPhoto(bytes);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      } finally {
        if (mounted) setState(() => _openingTryOn = false);
      }
    }
    if (photo != null && mounted) openTryOnWithPhoto(context, photo);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return VastraPage(
      appBar: AppBar(
        backgroundColor: VastraColors.ivory.withValues(alpha: 0.9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('Recreate a look'),
      ),
      child: AnimatedSwitcher(
        duration: 300.ms,
        child: _busy
            ? _Analysing(key: const ValueKey('busy'), photo: _photo)
            : result != null
            ? RecreateResultView(
                key: ValueKey(result.id),
                result: result,
                photo: _photo,
                wearing: _wearing,
                openingTryOn: _openingTryOn,
                onWear: () => _wearToday(result),
                onTryMine: () => _tryMyVersion(result),
                onTryOriginal: () => _tryOriginal(result),
                onTryPiece: (id) => openTryOn(context, id),
                onAnother: _reset,
              )
            : _Start(
                key: const ValueKey('start'),
                error: _error,
                recent: _recent,
                onSnap: () => _pick(camera: true),
                onUpload: () => _pick(camera: false),
                onRetry: _photo == null ? null : () => _analyse(_photo!),
                onOpen: (r) => setState(() {
                  _photo = null;
                  _result = r;
                }),
              ),
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({
    super.key,
    required this.error,
    required this.recent,
    required this.onSnap,
    required this.onUpload,
    required this.onRetry,
    required this.onOpen,
  });

  final String? error;
  final Stream<List<RecreateResult>>? recent;
  final VoidCallback onSnap;
  final VoidCallback onUpload;
  final VoidCallback? onRetry;
  final ValueChanged<RecreateResult> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const VastraHeading(
          'Seen a look you love?',
          subtitle: 'Street style, a Pinterest screenshot, a friend’s outfit — I’ll rebuild it from your closet.',
          size: 32,
        ),
        const SizedBox(height: 16),
        const PipSceneCard(PipScene.arranging, height: 170, caption: 'Pip is ready to raid your closet'),
        const SizedBox(height: 18),
        if (error != null) ...[
          VastraMessage(error!, isError: true),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try that photo again'),
              ),
            ),
          const SizedBox(height: 10),
        ],
        VastraPrimaryButton(label: 'Snap an outfit', icon: Icons.photo_camera_outlined, onPressed: onSnap),
        const SizedBox(height: 10),
        VastraSecondaryButton(label: 'Upload a photo', icon: Icons.photo_library_outlined, onPressed: onUpload),
        StreamBuilder<List<RecreateResult>>(
          stream: recent,
          builder: (context, snap) {
            final items = snap.data ?? const <RecreateResult>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 26),
                Text(
                  'Your recreations',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: VastraColors.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 176,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => _RecentTile(result: items[i], onTap: () => onOpen(items[i])),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.result, required this.onTap});

  final RecreateResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                VastraImage(result.imageUrl, width: 112, height: 136, radius: 18),
                Positioned(left: 6, bottom: 6, child: _ScoreBadge(score: result.score, small: true)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: VastraColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }
}

class _Analysing extends StatelessWidget {
  const _Analysing({super.key, required this.photo});

  final PickedPhoto? photo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Image.memory(photo!.bytes, height: 360, width: double.infinity, fit: BoxFit.cover),
                Positioned.fill(
                  child: Container(color: VastraColors.softWhite.withValues(alpha: 0.12))
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1600.ms, color: VastraColors.softWhite.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const PipSays(PipPose.searching, 'Spotting every piece… now raiding your closet for the closest matches 🔍'),
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 4, borderRadius: BorderRadius.all(Radius.circular(4))),
      ],
    );
  }
}

class RecreateResultView extends StatelessWidget {
  const RecreateResultView({
    super.key,
    required this.result,
    required this.photo,
    required this.wearing,
    required this.openingTryOn,
    required this.onWear,
    required this.onTryMine,
    required this.onTryOriginal,
    required this.onTryPiece,
    required this.onAnother,
  });

  final RecreateResult result;
  final PickedPhoto? photo;
  final bool wearing;
  final bool openingTryOn;
  final VoidCallback onWear;
  final VoidCallback onTryMine;
  final VoidCallback onTryOriginal;
  final ValueChanged<String> onTryPiece;
  final VoidCallback onAnother;

  PipPose get _pose => result.score >= 75
      ? PipPose.celebration
      : result.score >= 45
      ? PipPose.lovingIt
      : PipPose.thoughtful;

  @override
  Widget build(BuildContext context) {
    final matched = result.matchedItems;
    final inspiration = photo != null
        ? Image.memory(photo!.bytes, width: 128, height: 168, fit: BoxFit.cover)
        : VastraImage(result.imageUrl, width: 128, height: 168);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(22), child: inspiration),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.vibe.isNotEmpty) VastraPill(result.vibe, color: VastraColors.blush),
                  const SizedBox(height: 8),
                  Text(
                    result.title,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: VastraColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ScoreBadge(score: result.score),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 18),
        if (result.summary.isNotEmpty) PipSays(_pose, result.summary, size: 84),
        const SizedBox(height: 18),
        if (matched.isNotEmpty) ...[
          _SectionTitle('Your version'),
          const SizedBox(height: 10),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: matched.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => GarmentImage(
                imageUrl: matched[i].imageUrl,
                cutoutUrl: matched[i].tileCutoutUrl,
                width: 100,
                height: 128,
                radius: 18,
              ).animate().fadeIn(delay: (i * 80).ms).scale(begin: const Offset(0.9, 0.9)),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _SectionTitle('Piece by piece'),
        const SizedBox(height: 10),
        for (var i = 0; i < result.pieces.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PieceRow(
              piece: result.pieces[i],
              onTryOn: onTryPiece,
            ).animate().fadeIn(delay: (120 + i * 70).ms).slideY(begin: 0.05, end: 0),
          ),
        if (result.tip.isNotEmpty) ...[
          const SizedBox(height: 6),
          VastraSurface(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📌', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Pip’s tip  ',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.burgundy),
                        ),
                        TextSpan(text: result.tip),
                      ],
                    ),
                    style: GoogleFonts.outfit(fontSize: 14, height: 1.45, color: VastraColors.chocolate),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (matched.isNotEmpty) ...[
          VastraPrimaryButton(
            label: 'Wear my version today',
            icon: Icons.check_rounded,
            busy: wearing,
            onPressed: onWear,
          ),
          const SizedBox(height: 10),
          VastraSecondaryButton(label: 'Try my version on', icon: Icons.auto_awesome_outlined, onPressed: onTryMine),
          const SizedBox(height: 10),
        ],
        VastraSecondaryButton(
          label: openingTryOn ? 'Opening…' : 'Try the original look on me',
          icon: Icons.person_outline_rounded,
          onPressed: openingTryOn ? null : onTryOriginal,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: onAnother,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('Recreate another look'),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w600, color: VastraColors.charcoal),
  );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, this.small = false});

  final int score;
  final bool small;

  String get _label => score >= 80
      ? 'You’ve basically got it'
      : score >= 55
      ? 'Very doable'
      : score >= 30
      ? 'Halfway there'
      : 'A fresh direction';

  @override
  Widget build(BuildContext context) {
    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: VastraColors.softWhite.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$score%',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: VastraColors.burgundy),
        ),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: 900.ms,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: VastraColors.burgundy,
                  backgroundColor: VastraColors.blush,
                ),
              ),
              Text(
                '$score%',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: VastraColors.burgundy),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_label, style: GoogleFonts.outfit(fontSize: 13, height: 1.3, color: VastraColors.chocolate)),
        ),
      ],
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece, required this.onTryOn});

  final RecreatePiece piece;
  final ValueChanged<String> onTryOn;

  (String, Color, Color) get _badge => switch (piece.closeness) {
    'exact' => ('Perfect match', VastraColors.mint, VastraColors.success),
    'close' => ('Close match', VastraColors.mint.withValues(alpha: 0.6), VastraColors.success),
    'swap' => ('Clever swap', VastraColors.blush, VastraColors.burgundy),
    _ => ('Missing', VastraColors.ivoryDeep, VastraColors.muted),
  };

  @override
  Widget build(BuildContext context) {
    final item = piece.item;
    final (label, bg, fg) = _badge;
    return VastraSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item != null
              ? GarmentImage(
                  imageUrl: item.imageUrl,
                  cutoutUrl: item.tileCutoutUrl,
                  width: 66,
                  height: 84,
                  radius: 14,
                  padding: const EdgeInsets.all(5),
                )
              : Container(
                  width: 66,
                  height: 84,
                  decoration: BoxDecoration(
                    color: VastraColors.ivory,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: VastraColors.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.search_rounded, color: VastraColors.muted),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VastraPill(label, color: bg, textColor: fg),
                const SizedBox(height: 6),
                Text(
                  item?.name ?? 'Not in your closet yet',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: item != null ? VastraColors.charcoal : VastraColors.muted,
                  ),
                ),
                Text(
                  'In the photo: ${piece.piece}',
                  style: GoogleFonts.outfit(fontSize: 12.5, color: VastraColors.muted),
                ),
                if (piece.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(piece.note, style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: VastraColors.chocolate)),
                ],
              ],
            ),
          ),
          if (item != null)
            IconButton(
              tooltip: 'Try on',
              onPressed: () => onTryOn(item.id),
              icon: const Icon(Icons.auto_awesome_outlined, color: VastraColors.burgundy),
            ),
        ],
      ),
    );
  }
}
