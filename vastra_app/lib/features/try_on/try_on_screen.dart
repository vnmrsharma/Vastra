import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/picked_photo.dart';
import '../../providers/auth_controller.dart';
import '../../providers/try_on_request.dart';
import '../../services/functions_api.dart';
import '../../services/wardrobe_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

enum _Source { closet, photo }

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  final _api = const FunctionsApi();
  final _wardrobe = WardrobeService();
  StreamSubscription<List<WardrobeItem>>? _sub;
  Timer? _ticker;

  List<WardrobeItem> _items = [];
  _Source _source = _Source.closet;
  String? _selectedId;
  PickedPhoto? _photo;
  String _category = 'auto';
  bool _categoryTouched = false;

  bool _running = false;
  int _elapsed = 0;
  String? _stage;
  String? _error;
  String? _resultUrl;
  bool _comparing = false;
  bool _portraitUploading = false;

  late final TryOnRequest _request;

  @override
  void initState() {
    super.initState();
    _request = context.read<TryOnRequest>()..addListener(_takeRequest);
    final handoff = _request.take();
    if (handoff != null) _apply(handoff);
    final uid = context.read<AuthController>().uid;
    if (uid != null) {
      _sub = _wardrobe.watch(uid).listen((items) {
        if (!mounted) return;
        setState(() {
          _items = items;
          _syncCategory();
        });
      }, onError: (Object _) {});
    }
  }

  /// Picks up a piece or photo handed over from Today, the closet or Recreate.
  void _takeRequest() {
    if (_running || !_request.hasPending) return;
    final handoff = _request.take();
    if (handoff != null) setState(() => _apply(handoff));
  }

  void _apply(TryOnHandoff handoff) {
    _resultUrl = null;
    _error = null;
    if (handoff.photo != null) {
      _source = _Source.photo;
      _photo = handoff.photo;
      _category = handoff.category ?? 'full_body';
      _categoryTouched = true;
    } else {
      _source = _Source.closet;
      _selectedId = handoff.itemId;
      _categoryTouched = false;
      _syncCategory();
    }
  }

  @override
  void dispose() {
    _request.removeListener(_takeRequest);
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  WardrobeItem? get _selected {
    for (final item in _items) {
      if (item.id == _selectedId) return item;
    }
    return null;
  }

  bool get _hasGarment => _source == _Source.closet ? _selected != null : _photo != null;

  void _syncCategory() {
    if (_categoryTouched) return;
    _category = _source == _Source.closet ? (_selected?.garmentCategory ?? 'auto') : 'auto';
  }

  Future<void> _changePortrait() async {
    final auth = context.read<AuthController>();
    final files = await pickPhotos(
      context,
      title: 'New try-on portrait',
      subtitle: 'Stand straight, face the camera, just you in the frame.',
    );
    if (files.isEmpty || auth.uid == null) return;
    setState(() => _portraitUploading = true);
    try {
      await auth.profiles.uploadTryOnPhoto(uid: auth.uid!, photo: files.first);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _portraitUploading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final files = await pickPhotos(
      context,
      title: 'Try any photo',
      subtitle: 'A product shot, a Pinterest screenshot, or an outfit you love.',
    );
    if (files.isEmpty) return;
    setState(() {
      _photo = files.first;
      _source = _Source.photo;
      _resultUrl = null;
      _categoryTouched = false;
      _syncCategory();
    });
  }

  Future<void> _generate() async {
    final uid = context.read<AuthController>().uid;
    if (uid == null || !_hasGarment) return;

    setState(() {
      _running = true;
      _error = null;
      _resultUrl = null;
      _elapsed = 0;
      _stage = 'Pip is getting your photos ready…';
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed == 6) _stage = 'Pip’s behind the curtain while YouCam fits it on you…';
        if (_elapsed == 16) _stage = 'Adding the finishing touches…';
        if (_elapsed == 35) _stage = 'Almost there — Pip’s pinning the last bits…';
      });
    });

    try {
      final String jobId;
      if (_source == _Source.closet) {
        final item = _selected!;
        jobId = await _api.startTryOn(
          wardrobeItemId: item.id,
          garmentPreviewUrl: item.imageUrl,
          garmentCategory: _category,
          title: item.name,
        );
      } else {
        final uploaded = await _wardrobe.uploadImage(uid: uid, photo: _photo!, folder: 'garments');
        jobId = await _api.startTryOn(
          garmentPath: uploaded.path,
          garmentPreviewUrl: uploaded.url,
          garmentCategory: _category,
          title: 'From a photo',
        );
      }
      final url = await _api.waitForTryOn(jobId);
      if (mounted) setState(() => _resultUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      _ticker?.cancel();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final portrait = profile?.tryOnPhotoUrl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const VastraHeading('Try it on', subtitle: 'Real virtual try-on by YouCam. Every result is saved to Looks.'),
        const SizedBox(height: 16),
        if (_resultUrl != null)
          _ResultCard(
            resultUrl: _resultUrl!,
            portraitUrl: portrait,
            comparing: _comparing,
            onCompare: (v) => setState(() => _comparing = v),
            onAgain: () => setState(() => _resultUrl = null),
            onLooks: () => context.go('/app/looks'),
          ).animate().fadeIn(duration: 450.ms).scale(begin: const Offset(0.97, 0.97))
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Frame(
                  label: 'You',
                  action: portrait == null ? null : 'Change',
                  onAction: _running ? null : _changePortrait,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (portrait != null)
                        VastraImage(portrait)
                      else
                        _Placeholder(
                          icon: Icons.photo_camera_front_rounded,
                          text: 'Add your portrait',
                          onTap: _changePortrait,
                        ),
                      if (_portraitUploading)
                        Container(
                          color: VastraColors.softWhite.withValues(alpha: 0.6),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 120, left: 8, right: 8),
                child: Icon(Icons.favorite_rounded, color: VastraColors.blush, size: 22),
              ),
              Expanded(
                child: _Frame(
                  label: 'Wearing',
                  child: _source == _Source.photo && _photo != null
                      ? Image.memory(_photo!.bytes, fit: BoxFit.cover, cacheWidth: 700)
                      : _selected != null
                      ? GarmentImage(imageUrl: _selected!.imageUrl, cutoutUrl: _selected!.cutoutUrl)
                      : _Placeholder(icon: Icons.checkroom_rounded, text: 'Pick below', onTap: _pickPhoto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          VastraSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Source>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: VastraColors.blush,
                    selectedForegroundColor: VastraColors.burgundy,
                    side: const BorderSide(color: VastraColors.border),
                  ),
                  segments: const [
                    ButtonSegment(value: _Source.closet, icon: Icon(Icons.checkroom_rounded), label: Text('My closet')),
                    ButtonSegment(value: _Source.photo, icon: Icon(Icons.image_outlined), label: Text('Any photo')),
                  ],
                  selected: {_source},
                  onSelectionChanged: _running
                      ? null
                      : (s) => setState(() {
                          _source = s.first;
                          _categoryTouched = false;
                          _syncCategory();
                        }),
                ),
                const SizedBox(height: 14),
                if (_source == _Source.closet)
                  _ClosetStrip(
                    items: _items,
                    selectedId: _selectedId,
                    onSelect: (id) => setState(() {
                      _selectedId = id;
                      _categoryTouched = false;
                      _syncCategory();
                    }),
                    onEmpty: () => context.go('/app/closet'),
                  )
                else
                  VastraSecondaryButton(
                    label: _photo == null ? 'Choose a photo' : 'Choose a different photo',
                    icon: Icons.add_photo_alternate_outlined,
                    onPressed: _running ? null : _pickPhoto,
                  ),
                const SizedBox(height: 14),
                Text(
                  'What should YouCam change?',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: VastraColors.chocolate),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: garmentCategories
                      .map(
                        (c) => ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(garmentLabel(c)),
                          selected: _category == c,
                          onSelected: _running
                              ? null
                              : (_) => setState(() {
                                  _category = c;
                                  _categoryTouched = true;
                                }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                VastraPrimaryButton(
                  label: portrait == null
                      ? 'Add your portrait first'
                      : !_hasGarment
                      ? 'Pick something to try'
                      : 'Try it on',
                  icon: Icons.auto_awesome_rounded,
                  busy: _running,
                  onPressed: portrait == null
                      ? _changePortrait
                      : _hasGarment
                      ? _generate
                      : null,
                ),
                if (_error != null) ...[const SizedBox(height: 12), VastraMessage(_error!, isError: true)],
              ],
            ),
          ),
          if (_running) ...[const SizedBox(height: 16), _Progress(stage: _stage ?? '', seconds: _elapsed)],
        ],
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.label, required this.child, this.action, this.onAction});

  final String label;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.chocolate),
                ),
              ),
              const Spacer(),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(action!),
                ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: VastraColors.softWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: VastraColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: VastraColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(text, style: GoogleFonts.outfit(fontSize: 13, color: VastraColors.muted)),
        ],
      ),
    );
  }
}

class _ClosetStrip extends StatelessWidget {
  const _ClosetStrip({required this.items, required this.selectedId, required this.onSelect, required this.onEmpty});

  final List<WardrobeItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return VastraSecondaryButton(label: 'Add pieces to your closet', icon: Icons.add_rounded, onPressed: onEmpty);
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = item.id == selectedId;
          return TapTarget(
            onTap: () => onSelect(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 78,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? VastraColors.burgundy : Colors.transparent, width: 2.5),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GarmentImage(
                    imageUrl: item.imageUrl,
                    cutoutUrl: item.tileCutoutUrl,
                    radius: 14,
                    padding: const EdgeInsets.all(6),
                  ),
                  if (selected)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: VastraColors.burgundy,
                        child: Icon(Icons.check_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.stage, required this.seconds});

  final String stage;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return VastraSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PipSceneCard(PipScene.changing, height: 210, caption: stage),
          const SizedBox(height: 12),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(99)),
            child: LinearProgressIndicator(minHeight: 5),
          ),
          const SizedBox(height: 8),
          Text(
            '${seconds}s · usually 15–30s · feel free to browse other tabs',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.resultUrl,
    required this.portraitUrl,
    required this.comparing,
    required this.onCompare,
    required this.onAgain,
    required this.onLooks,
  });

  final String resultUrl;
  final String? portraitUrl;
  final bool comparing;
  final ValueChanged<bool> onCompare;
  final VoidCallback onAgain;
  final VoidCallback onLooks;

  @override
  Widget build(BuildContext context) {
    return VastraSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
            child: Row(
              children: [
                const Pip(PipPose.rampwalk, size: 58),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Here you are ✨',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: VastraColors.charcoal,
                    ),
                  ),
                ),
                const VastraPill('Saved to Looks', color: VastraColors.mint, textColor: VastraColors.success),
              ],
            ),
          ),
          GestureDetector(
            onLongPressStart: (_) => onCompare(true),
            onLongPressEnd: (_) => onCompare(false),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: comparing && portraitUrl != null
                      ? VastraImage(portraitUrl, key: const ValueKey('before'))
                      : VastraImage(resultUrl, key: const ValueKey('after')),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            comparing ? 'Original photo' : 'Press and hold to compare',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VastraSecondaryButton(label: 'Try another', icon: Icons.refresh_rounded, onPressed: onAgain),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VastraPrimaryButton(label: 'My looks', icon: Icons.favorite_rounded, onPressed: onLooks),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
