import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/picked_photo.dart';
import '../../providers/auth_controller.dart';
import '../../providers/today_controller.dart';
import '../../services/functions_api.dart';
import '../../services/wardrobe_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';
import '../closet/snap_camera_screen.dart';

enum _Step { hello, city, style, week, portrait, closet, done }

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _page;
  final _city = TextEditingController();
  final _notes = TextEditingController();
  final _wardrobe = WardrobeService();

  late final AuthController _auth;
  late int _index;
  String _presentation = 'prefer_not';
  final Set<String> _vibes = {};
  final Set<String> _colours = {};
  final Set<String> _occasions = {};

  PickedPhoto? _portraitLocal;
  bool _portraitUploading = false;
  final List<PickedPhoto> _pendingUploads = [];
  bool _detectingCity = false;
  bool _saving = false;
  String? _error;
  Stream<List<WardrobeItem>>? _closet;

  static final _steps = _Step.values;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    final p = _auth.profile;
    _city.text = p?.preferredCity ?? '';
    _notes.text = p?.styleNotes ?? '';
    _presentation = p?.genderPresentation ?? 'prefer_not';
    _vibes.addAll(p?.vibes ?? const []);
    _colours.addAll(p?.favouriteColours ?? const []);
    _occasions.addAll(p?.occasions ?? const []);

    final editing = p?.onboardingComplete == true;
    _index = editing ? 1 : (p?.onboardingStep ?? 0).clamp(0, _steps.length - 1);
    _page = PageController(initialPage: _index);
    if (_auth.uid != null) _closet = _wardrobe.watch(_auth.uid!);
  }

  @override
  void dispose() {
    _page.dispose();
    _city.dispose();
    _notes.dispose();
    super.dispose();
  }

  _Step get _step => _steps[_index];
  bool get _editing => _auth.profile?.onboardingComplete == true;

  Map<String, dynamic> _dataFor(_Step step) {
    switch (step) {
      case _Step.city:
        return {'preferredCity': _city.text.trim().isEmpty ? null : _city.text.trim()};
      case _Step.style:
        return {'genderPresentation': _presentation, 'vibes': _vibes.toList(), 'favouriteColours': _colours.toList()};
      case _Step.week:
        return {'occasions': _occasions.toList(), 'styleNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim()};
      default:
        return {};
    }
  }

  Future<void> _goTo(int index) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _index = index;
      _error = null;
    });
    await _page.animateToPage(index, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Future<void> _continue({bool save = true}) async {
    if (save && _step == _Step.city && _city.text.trim().isEmpty) {
      setState(() => _error = 'Add your city — or tap “Detect my city”.');
      return;
    }
    if (_step == _Step.done) return _finish();

    final next = _index + 1;
    // Saving never blocks the animation; the profile stream catches up.
    unawaited(
      _auth.updateProfile({if (save) ..._dataFor(_step), if (!_editing) 'onboardingStep': next}).catchError((Object e) {
        if (mounted) setState(() => _error = friendlyError(e));
      }),
    );
    await _goTo(next);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await _auth.updateProfile({
        ..._dataFor(_Step.city),
        ..._dataFor(_Step.style),
        ..._dataFor(_Step.week),
        'onboardingComplete': true,
        'onboardingStep': _steps.length - 1,
      });
      if (!mounted) return;
      context.read<TodayController>().invalidate();
      context.go('/app');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _detectCity() async {
    setState(() {
      _detectingCity = true;
      _error = null;
    });
    final city = await FunctionsApi.detectCity();
    if (!mounted) return;
    setState(() {
      _detectingCity = false;
      if (city != null) {
        _city.text = city;
      } else {
        _error = 'Couldn’t detect your city — type it in instead.';
      }
    });
  }

  Future<void> _pickPortrait() async {
    final files = await pickPhotos(
      context,
      title: 'Your try-on portrait',
      subtitle: 'Stand straight, face the camera, just you in the frame.',
    );
    if (files.isEmpty || _auth.uid == null) return;
    setState(() {
      _portraitLocal = files.first;
      _portraitUploading = true;
      _error = null;
    });
    try {
      await _auth.profiles.uploadTryOnPhoto(uid: _auth.uid!, photo: files.first);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _portraitUploading = false);
    }
  }

  Future<void> _snapCloset() async {
    if (_auth.uid == null) return;
    await SnapCameraScreen.open(context, _auth.uid!);
  }

  Future<void> _closetFromLibrary() async {
    final files = await pickFromLibrary(context, multiple: true);
    if (files.isEmpty || _auth.uid == null) return;
    setState(() => _pendingUploads.addAll(files));
    await Future.wait(
      files.map((file) async {
        try {
          await _wardrobe.addFromPhoto(uid: _auth.uid!, photo: file);
        } catch (e) {
          if (mounted) setState(() => _error = friendlyError(e));
        } finally {
          if (mounted) setState(() => _pendingUploads.remove(file));
        }
      }),
    );
  }

  String _primaryLabel(int closetCount) {
    switch (_step) {
      case _Step.hello:
        return 'Let’s go';
      case _Step.portrait:
        final hasPortrait = _portraitLocal != null || _auth.profile?.tryOnPhotoUrl != null;
        return hasPortrait ? 'Looks great' : 'Skip for now';
      case _Step.closet:
        if (_pendingUploads.isNotEmpty) return 'Uploading…';
        return closetCount == 0 ? 'Skip for now' : 'Continue';
      case _Step.done:
        return _editing ? 'Save & go back' : 'Enter Vastra';
      default:
        return 'Continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;

    return PopScope(
      canPop: _index == 0 || (_editing && _index <= 1),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0) _goTo(_index - 1);
      },
      child: VastraPage(
        child: StreamBuilder<List<WardrobeItem>>(
          stream: _closet,
          builder: (context, snap) {
            final closet = snap.data ?? const <WardrobeItem>[];
            return Column(
              children: [
                _TopBar(
                  index: _index,
                  total: _steps.length,
                  canGoBack: _index > (_editing ? 1 : 0),
                  canSkip: _step != _Step.hello && _step != _Step.done,
                  onBack: () => _goTo(_index - 1),
                  onSkip: () => _continue(save: false),
                  onClose: _editing ? () => context.go('/app') : null,
                ),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _HelloStep(name: profile?.firstName ?? 'there'),
                      _CityStep(city: _city, detecting: _detectingCity, onDetect: _detectCity),
                      _StyleStep(
                        presentation: _presentation,
                        vibes: _vibes,
                        colours: _colours,
                        onPresentation: (v) => setState(() => _presentation = v),
                        onToggleVibe: (v) => setState(() => _vibes.contains(v) ? _vibes.remove(v) : _vibes.add(v)),
                        onToggleColour: (v) =>
                            setState(() => _colours.contains(v) ? _colours.remove(v) : _colours.add(v)),
                      ),
                      _WeekStep(
                        selected: _occasions,
                        notes: _notes,
                        onToggle: (v) =>
                            setState(() => _occasions.contains(v) ? _occasions.remove(v) : _occasions.add(v)),
                      ),
                      _PortraitStep(
                        local: _portraitLocal,
                        remoteUrl: profile?.tryOnPhotoUrl,
                        uploading: _portraitUploading,
                        onPick: _pickPortrait,
                      ),
                      _ClosetStep(
                        items: closet,
                        pending: _pendingUploads,
                        onSnap: _snapCloset,
                        onLibrary: _closetFromLibrary,
                      ),
                      _DoneStep(
                        city: _city.text.trim(),
                        vibes: _vibes.toList(),
                        hasPortrait: profile?.tryOnPhotoUrl != null,
                        closetCount: closet.length,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
                  child: Column(
                    children: [
                      if (_error != null) ...[VastraMessage(_error!, isError: true), const SizedBox(height: 10)],
                      VastraPrimaryButton(
                        label: _primaryLabel(closet.length),
                        busy: _saving,
                        onPressed: (_step == _Step.closet && _pendingUploads.isNotEmpty) || _portraitUploading
                            ? null
                            : () => _continue(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.total,
    required this.canGoBack,
    required this.canSkip,
    required this.onBack,
    required this.onSkip,
    this.onClose,
  });

  final int index;
  final int total;
  final bool canGoBack;
  final bool canSkip;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: canGoBack
                ? IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded))
                : onClose != null
                ? IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded))
                : null,
          ),
          Expanded(
            child: StepDots(total: total, index: index),
          ),
          SizedBox(
            width: 64,
            child: canSkip ? TextButton(onPressed: onSkip, child: const Text('Skip')) : null,
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        for (var i = 0; i < children.length; i++)
          children[i].animate().fadeIn(delay: (i * 55).ms, duration: 320.ms).slideY(begin: 0.04, end: 0),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.hint, required this.child});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return VastraSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: GoogleFonts.outfit(fontSize: 13, color: VastraColors.muted)),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HelloStep extends StatelessWidget {
  const _HelloStep({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      children: [
        PipSays(PipPose.happy, 'Hi $name! I’m Pip, your style sidekick. Let’s make Vastra yours 💕', size: 150),
        const SizedBox(height: 18),
        VastraHeading(
          'Hi $name,\nlet’s make this yours',
          subtitle: 'About two minutes. Everything can be changed later.',
          size: 38,
        ),
        const SizedBox(height: 22),
        const VastraSurface(
          child: Column(
            children: [
              _Bullet(Icons.location_on_rounded, 'Your city', 'so looks follow the weather'),
              _Bullet(Icons.palette_rounded, 'Your aesthetic', 'cottagecore, minimal, grunge… and your colours'),
              _Bullet(Icons.photo_camera_front_rounded, 'A portrait', 'the photo YouCam dresses'),
              _Bullet(Icons.checkroom_rounded, 'A few favourites', 'we name and sort them for you', last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.title, this.detail, {this.last = false});

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: VastraColors.blush, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: VastraColors.burgundy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                ),
                Text(detail, style: GoogleFonts.outfit(fontSize: 13, color: VastraColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityStep extends StatelessWidget {
  const _CityStep({required this.city, required this.detecting, required this.onDetect});

  final TextEditingController city;
  final bool detecting;
  final VoidCallback onDetect;

  static const _quick = ['London', 'Manchester', 'Edinburgh', 'Birmingham', 'Bristol', 'Leeds'];

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      children: [
        const PipSays(PipPose.searching, 'Where are we getting dressed? I’ll keep an eye on the sky for you.'),
        const SizedBox(height: 12),
        const VastraHeading('Where do you get dressed?', subtitle: 'We check the sky here before suggesting layers.'),
        const SizedBox(height: 20),
        VastraSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VastraSecondaryButton(
                label: detecting ? 'Finding you…' : 'Detect my city',
                icon: Icons.my_location_rounded,
                onPressed: detecting ? null : onDetect,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: city,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. London',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: city,
                builder: (context, value, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quick
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c),
                          selected: value.text.trim().toLowerCase() == c.toLowerCase(),
                          onSelected: (_) => city.text = c,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StyleStep extends StatelessWidget {
  const _StyleStep({
    required this.presentation,
    required this.vibes,
    required this.colours,
    required this.onPresentation,
    required this.onToggleVibe,
    required this.onToggleColour,
  });

  final String presentation;
  final Set<String> vibes;
  final Set<String> colours;
  final ValueChanged<String> onPresentation;
  final ValueChanged<String> onToggleVibe;
  final ValueChanged<String> onToggleColour;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      children: [
        const PipSays(PipPose.thoughtful, 'Ooh, tell me your vibe… cottagecore? grunge? a little bit of everything?'),
        const SizedBox(height: 12),
        const VastraHeading('What’s your aesthetic?', subtitle: 'Pick whatever feels like you — mix and match freely.'),
        const SizedBox(height: 18),
        _Section(
          title: 'Your aesthetic',
          hint: 'Choose as many as you like',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: aesthetics.entries
                .map(
                  (e) => FilterChip(
                    avatar: ChipEmoji(e.value),
                    label: Text(e.key),
                    selected: vibes.contains(e.key),
                    onSelected: (_) => onToggleVibe(e.key),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Colours you love',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colourSwatches.entries.map((e) {
              final selected = colours.contains(e.key);
              return Tooltip(
                message: e.key,
                child: TapTarget(
                  onTap: () => onToggleColour(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(e.value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? VastraColors.burgundy : VastraColors.border,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Color(e.value).computeLuminance() > 0.5 ? VastraColors.charcoal : Colors.white,
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'How do you like to dress?',
          hint: 'Helps try-ons and suggestions feel right',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presentations.entries
                .map(
                  (e) => ChoiceChip(
                    label: Text(e.value),
                    selected: presentation == e.key,
                    onSelected: (_) => onPresentation(e.key),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _WeekStep extends StatelessWidget {
  const _WeekStep({required this.selected, required this.notes, required this.onToggle});

  final Set<String> selected;
  final TextEditingController notes;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      children: [
        const PipSays(PipPose.cheerful, 'Noting it all down! What are you usually dressing for?'),
        const SizedBox(height: 12),
        const VastraHeading(
          'What does your week look like?',
          subtitle: 'We’ll lead with the occasions you dress for most.',
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Usually dressing for',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: occasions.map((o) {
              final isOn = selected.contains(o);
              return Material(
                color: isOn ? VastraColors.blush : VastraColors.ivory,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onToggle(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isOn ? VastraColors.burgundySoft : VastraColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(occasionIcons[o] ?? '', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            occasionLabel(o),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                              color: isOn ? VastraColors.burgundy : VastraColors.charcoal,
                            ),
                          ),
                        ),
                        if (isOn) const Icon(Icons.check_circle_rounded, size: 18, color: VastraColors.burgundy),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Anything else? (optional)',
          child: TextField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Love linen, never neon, always comfy shoes…'),
          ),
        ),
      ],
    );
  }
}

class _PortraitStep extends StatelessWidget {
  const _PortraitStep({required this.local, required this.remoteUrl, required this.uploading, required this.onPick});

  final PickedPhoto? local;
  final String? remoteUrl;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = local != null || remoteUrl != null;
    return _StepBody(
      children: [
        const PipSays(PipPose.outfitReveal, 'Strike a pose! Stand tall, face me, and I’ll dress you in anything.'),
        const SizedBox(height: 12),
        const VastraHeading('Your try-on portrait', subtitle: 'This is the photo YouCam dresses — make it a good one.'),
        const SizedBox(height: 18),
        Center(
          child: TapTarget(
            onTap: uploading ? null : onPick,
            child: Container(
              width: 230,
              height: 306,
              decoration: BoxDecoration(
                color: VastraColors.softWhite,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: hasPhoto ? VastraColors.burgundySoft : VastraColors.border,
                  width: hasPhoto ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: VastraColors.chocolate.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (local != null)
                    Image.memory(local!.bytes, fit: BoxFit.cover, cacheWidth: 700)
                  else if (remoteUrl != null)
                    VastraImage(remoteUrl)
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.accessibility_new_rounded,
                          size: 64,
                          color: VastraColors.muted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 10),
                        Text('Tap to add your photo', style: GoogleFonts.outfit(color: VastraColors.muted)),
                      ],
                    ),
                  if (uploading)
                    Container(
                      color: VastraColors.softWhite.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  if (hasPhoto && !uploading)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: VastraColors.softWhite.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: VastraColors.success),
                            const SizedBox(width: 4),
                            Text('Saved', style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.success)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: VastraSecondaryButton(
            label: hasPhoto ? 'Use a different photo' : 'Add photo',
            icon: Icons.photo_camera_outlined,
            expanded: false,
            onPressed: uploading ? null : onPick,
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            VastraPill('🧍 Standing, facing forward', color: VastraColors.mint, textColor: VastraColors.success),
            VastraPill('🙂 Face visible', color: VastraColors.mint, textColor: VastraColors.success),
            VastraPill('👤 Just you', color: VastraColors.mint, textColor: VastraColors.success),
            VastraPill('☀️ Good light', color: VastraColors.mint, textColor: VastraColors.success),
          ],
        ),
      ],
    );
  }
}

class _ClosetStep extends StatelessWidget {
  const _ClosetStep({required this.items, required this.pending, required this.onSnap, required this.onLibrary});

  final List<WardrobeItem> items;
  final List<PickedPhoto> pending;
  final VoidCallback onSnap;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    const goal = 3;
    return _StepBody(
      children: [
        const PipSays(
          PipPose.lovingIt,
          'My favourite part! Snap your clothes one after another — I’ll name every piece.',
        ),
        const SizedBox(height: 12),
        const VastraHeading(
          'Snap a few favourites',
          subtitle:
              'Open the camera and snap your clothes one after another — each saves instantly and Gemini names it.',
        ),
        const SizedBox(height: 16),
        VastraPrimaryButton(label: 'Open camera', icon: Icons.photo_camera_rounded, onPressed: onSnap),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: onLibrary, child: const Text('or pick from your library')),
        ),
        const SizedBox(height: 8),
        VastraSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count >= goal ? 'Lovely — $count pieces in your closet' : '$count of $goal pieces',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                    ),
                  ),
                  if (count >= goal) const Icon(Icons.favorite_rounded, color: VastraColors.burgundy, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: (count / goal).clamp(0, 1).toDouble(), minHeight: 6),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
                children: [
                  _AddTile(onTap: onSnap),
                  for (final file in pending) _PendingTile(file: file),
                  for (final item in items) _ItemTile(item: item),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VastraColors.blush.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: VastraColors.burgundy),
            const SizedBox(height: 6),
            Text(
              'Add',
              style: GoogleFonts.outfit(color: VastraColors.burgundy, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.file});
  final PickedPhoto file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(file.bytes, fit: BoxFit.cover, cacheWidth: 400),
          Container(color: VastraColors.softWhite.withValues(alpha: 0.55)),
          const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GarmentImage(imageUrl: item.imageUrl, cutoutUrl: item.tileCutoutUrl),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, VastraColors.charcoal.withValues(alpha: 0.65)],
                ),
              ),
              child: Text(
                item.tagging ? 'Naming…' : item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.92, 0.92));
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.city, required this.vibes, required this.hasPortrait, required this.closetCount});

  final String city;
  final List<String> vibes;
  final bool hasPortrait;
  final int closetCount;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      children: [
        const PipSays(
          PipPose.celebration,
          'Yay! Everything’s pinned in place. Let’s go get dressed!',
          size: 150,
          emphasis: true,
        ),
        const SizedBox(height: 18),
        VastraHeading(
          'You’re all set',
          subtitle: city.isEmpty
              ? 'Your little dressing room is ready.'
              : 'Dressing for $city — today’s looks are waiting.',
          size: 38,
        ),
        const SizedBox(height: 20),
        VastraSurface(
          child: Column(
            children: [
              _Check(done: city.isNotEmpty, label: city.isNotEmpty ? 'City: $city' : 'No city yet — add it any time'),
              _Check(
                done: vibes.isNotEmpty,
                label: vibes.isNotEmpty
                    ? 'Aesthetic: ${vibes.take(3).map((v) => '${aesthetics[v] ?? ''} $v'.trim()).join(', ')}'
                    : 'Aesthetic left open',
              ),
              _Check(
                done: hasPortrait,
                label: hasPortrait ? 'Try-on portrait ready' : 'Add a portrait to unlock try-on',
              ),
              _Check(
                done: closetCount > 0,
                label: closetCount > 0
                    ? '$closetCount piece${closetCount == 1 ? '' : 's'} in your closet'
                    : 'Closet ready for your first piece',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done, required this.label, this.last = false});

  final bool done;
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? VastraColors.success : VastraColors.muted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: GoogleFonts.outfit(color: VastraColors.charcoal)),
          ),
        ],
      ),
    );
  }
}
