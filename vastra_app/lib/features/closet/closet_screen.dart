import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/picked_photo.dart';
import '../../providers/auth_controller.dart';
import '../recreate/recreate_screen.dart';
import '../../providers/today_controller.dart';
import '../../providers/try_on_request.dart';
import '../../services/wardrobe_service.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';
import 'snap_camera_screen.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  final _wardrobe = WardrobeService();
  Stream<List<WardrobeItem>>? _stream;
  String? _streamUid;
  String _filter = 'all';
  final List<PickedPhoto> _pending = [];

  Stream<List<WardrobeItem>> _itemsFor(String uid) {
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = _wardrobe.watch(uid);
    }
    return _stream!;
  }

  Future<void> _snap(String uid) async {
    final today = context.read<TodayController>();
    final saved = await SnapCameraScreen.open(context, uid);
    if (saved == 0 || !mounted) return;
    today.invalidate();
    _toast('$saved piece${saved == 1 ? '' : 's'} added — naming them now ✨');
  }

  Future<void> _fromLibrary(String uid) async {
    final files = await pickFromLibrary(context, multiple: true);
    if (files.isEmpty || !mounted) return;
    final today = context.read<TodayController>();
    setState(() => _pending.addAll(files));
    var failed = 0;
    await Future.wait(
      files.map((file) async {
        try {
          await _wardrobe.addFromPhoto(uid: uid, photo: file);
        } catch (_) {
          failed++;
        } finally {
          if (mounted) setState(() => _pending.remove(file));
        }
      }),
    );
    today.invalidate();
    if (!mounted) return;
    final added = files.length - failed;
    _toast(
      failed == 0
          ? 'Added $added piece${added == 1 ? '' : 's'} ✨'
          : 'Added $added, $failed didn’t upload — check your connection.',
    );
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openItem(String uid, WardrobeItem item) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(uid: uid, item: item, service: _wardrobe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<WardrobeItem>>(
      stream: _itemsFor(uid),
      builder: (context, snap) {
        final all = snap.data ?? const <WardrobeItem>[];
        _wardrobe.ensureCutouts(all);
        bool rarelyWorn(WardrobeItem i) =>
            (i.daysSinceWorn ?? 999) >= 21 &&
            DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(i.createdAt)).inDays >= 7;
        final items = switch (_filter) {
          'all' => all,
          'rare' => all.where(rarelyWorn).toList(),
          _ => all.where((i) => i.category == _filter).toList(),
        };
        final usedCategories = wardrobeCategories.where((c) => all.any((i) => i.category == c)).toList();
        final hasRare = all.any(rarelyWorn);

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: VastraHeading(
                      'My closet',
                      subtitle: all.isEmpty
                          ? 'Your pieces live here, synced everywhere.'
                          : '${all.length} pieces · tap one to edit or try on',
                    ),
                  ),
                ),
                if (all.isNotEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    sliver: SliverToBoxAdapter(child: RecreateNudge()),
                  ),
                if (usedCategories.length > 1 || hasRare)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          for (final c in ['all', if (hasRare) 'rare', ...usedCategories])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: c == 'rare' ? const ChipEmoji('💤') : null,
                                label: Text(
                                  c == 'all'
                                      ? 'All'
                                      : c == 'rare'
                                      ? 'Rarely worn'
                                      : categoryLabel(c),
                                ),
                                selected: _filter == c,
                                onSelected: (_) => setState(() => _filter = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (!snap.hasData)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (all.isEmpty && _pending.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: VastraEmptyState(
                        scene: PipScene.arranging,
                        title: 'Your closet is empty',
                        description: 'Open the camera and snap your clothes one after another — each one saves instantly and gets named for you.',
                        action: Column(
                          children: [
                            FilledButton.icon(
                              onPressed: () => _snap(uid),
                              icon: const Icon(Icons.photo_camera_rounded),
                              label: const Text('Snap my clothes'),
                            ),
                            TextButton(
                              onPressed: () => _fromLibrary(uid),
                              child: const Text('or add from your library'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _pending.length + items.length,
                      itemBuilder: (context, i) {
                        if (i < _pending.length) return _PendingCard(photo: _pending[i]);
                        final item = items[i - _pending.length];
                        return _ItemCard(
                          item: item,
                          onTap: () => _openItem(uid, item),
                        ).animate().fadeIn(duration: 280.ms);
                      },
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: Row(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'closet-library',
                    tooltip: 'Add from library',
                    onPressed: () => _fromLibrary(uid),
                    backgroundColor: VastraColors.softWhite,
                    foregroundColor: VastraColors.burgundy,
                    elevation: 2,
                    child: const Icon(Icons.photo_library_outlined),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.extended(
                    heroTag: 'closet-snap',
                    onPressed: () => _snap(uid),
                    backgroundColor: VastraColors.burgundy,
                    foregroundColor: VastraColors.softWhite,
                    elevation: 2,
                    shape: const StadiumBorder(),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: Text('Snap clothes', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});

  final WardrobeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VastraColors.softWhite,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: VastraColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GarmentImage(
                  imageUrl: item.imageUrl,
                  cutoutUrl: item.tileCutoutUrl,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: item.tagging
                    ? Row(
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('Naming…', style: GoogleFonts.outfit(color: VastraColors.muted)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: VastraColors.charcoal),
                          ),
                          Text(
                            [categoryLabel(item.category), if (item.colour.isNotEmpty) item.colour].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted),
                          ),
                          Text(
                            item.wearCount == 0 ? 'Not worn yet' : 'Worn ${item.wearCount}×',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: item.wearCount == 0 ? VastraColors.burgundySoft : VastraColors.success,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.photo});
  final PickedPhoto photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(photo.bytes, fit: BoxFit.cover, cacheWidth: 500),
          Container(color: VastraColors.softWhite.withValues(alpha: 0.55)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text('Uploading…', style: GoogleFonts.outfit(color: VastraColors.chocolate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.uid, required this.item, required this.service});

  final String uid;
  final WardrobeItem item;
  final WardrobeService service;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _colour = TextEditingController(text: widget.item.colour);
  late String _category = widget.item.category;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _colour.dispose();
    super.dispose();
  }

  bool get _changed =>
      _name.text.trim() != widget.item.name ||
      _colour.text.trim() != widget.item.colour ||
      _category != widget.item.category;

  Future<void> _saveIfChanged() async {
    if (!_changed) return;
    await widget.service.updateItem(widget.uid, widget.item.id, {
      'name': _name.text.trim().isEmpty ? widget.item.name : _name.text.trim(),
      'colour': _colour.text.trim(),
      'category': _category,
    });
  }

  Future<void> _tryOn() async {
    setState(() => _busy = true);
    await _saveIfChanged();
    if (!mounted) return;
    final router = GoRouter.of(context);
    final request = context.read<TryOnRequest>();
    Navigator.pop(context);
    request.request(widget.item.id);
    router.go('/app/try-on');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this piece?'),
        content: Text('“${widget.item.name}” will leave your closet on every device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final today = context.read<TodayController>();
    Navigator.pop(context);
    await widget.service.deleteItem(widget.uid, widget.item);
    today.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 260,
              child: widget.item.cutoutUrl != null
                  ? GarmentImage(
                      imageUrl: widget.item.imageUrl,
                      cutoutUrl: widget.item.cutoutUrl,
                      radius: 20,
                      padding: const EdgeInsets.all(16),
                    )
                  : VastraImage(widget.item.imageUrl, fit: BoxFit.contain, radius: 20),
            ),
            const SizedBox(height: 10),
            Center(
              child: VastraPill(
                widget.item.wearLabel,
                color: widget.item.wearCount == 0 ? VastraColors.blush : VastraColors.mint,
                textColor: widget.item.wearCount == 0 ? VastraColors.burgundy : VastraColors.success,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colour,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Colour'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wardrobeCategories
                  .map(
                    (c) => ChoiceChip(
                      label: Text(categoryLabel(c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            VastraPrimaryButton(label: 'Try it on', icon: Icons.auto_awesome_rounded, busy: _busy, onPressed: _tryOn),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: VastraSecondaryButton(
                    label: _changed ? 'Save changes' : 'Done',
                    onPressed: () async {
                      await _saveIfChanged();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: _delete,
                  style: IconButton.styleFrom(side: const BorderSide(color: VastraColors.border)),
                  icon: const Icon(Icons.delete_outline_rounded, color: VastraColors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
