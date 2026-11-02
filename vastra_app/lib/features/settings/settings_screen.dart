import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_controller.dart';
import '../../providers/today_controller.dart';
import '../../services/functions_api.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _portraitBusy = false;
  bool _deleting = false;

  Future<void> _editText({required String title, required String initial, required String field, String? hint}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final trimmed = value.trim();
    await context.read<AuthController>().updateProfile({field: trimmed.isEmpty ? null : trimmed});
    if (field == 'preferredCity' && mounted) context.read<TodayController>().invalidate();
  }

  Future<void> _changePortrait() async {
    final auth = context.read<AuthController>();
    final photos = await pickPhotos(
      context,
      title: 'New try-on portrait',
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'This permanently removes your account, closet photos, portrait, try-ons and preferences. It can’t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep my account')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VastraColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthController>();
    setState(() => _deleting = true);
    try {
      await const FunctionsApi().deleteAccount();
      await auth.signOut();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final p = auth.profile;

    return VastraPage(
      appBar: AppBar(
        backgroundColor: VastraColors.ivory.withValues(alpha: 0.9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/app'),
        ),
        title: const Text('You'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: TapTarget(
              onTap: _portraitBusy ? null : _changePortrait,
              child: Stack(
                children: [
                  Container(
                    width: 112,
                    height: 140,
                    decoration: BoxDecoration(
                      color: VastraColors.blush,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: VastraColors.softWhite, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: VastraColors.chocolate.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _portraitBusy
                        ? const Center(child: CircularProgressIndicator())
                        : p?.tryOnPhotoUrl != null
                        ? VastraImage(p!.tryOnPhotoUrl)
                        : const Icon(Icons.person_rounded, size: 48, color: VastraColors.burgundy),
                  ),
                  const Positioned(
                    right: 6,
                    bottom: 6,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: VastraColors.burgundy,
                      child: Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              p?.displayName.isNotEmpty == true ? p!.displayName : 'Your profile',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: VastraColors.charcoal,
              ),
            ),
          ),
          Center(
            child: Text(p?.email ?? '', style: GoogleFonts.outfit(color: VastraColors.muted)),
          ),
          const SizedBox(height: 22),
          _Group(
            title: 'About you',
            children: [
              _Row(
                icon: Icons.person_outline_rounded,
                label: 'Name',
                value: p?.displayName ?? '',
                onTap: () => _editText(title: 'Your name', initial: p?.displayName ?? '', field: 'displayName'),
              ),
              _Row(
                icon: Icons.location_on_outlined,
                label: 'City',
                value: p?.preferredCity ?? 'Add for weather',
                onTap: () => _editText(
                  title: 'Your city',
                  initial: p?.preferredCity ?? '',
                  field: 'preferredCity',
                  hint: 'e.g. London',
                ),
              ),
              _Row(
                icon: Icons.palette_outlined,
                label: 'Aesthetic',
                value: p == null || p.vibes.isEmpty
                    ? 'Choose yours'
                    : p.vibes.take(2).map((v) => '${aesthetics[v] ?? ''} $v'.trim()).join(', '),
                onTap: () => context.go('/onboarding'),
              ),
              _Row(
                icon: Icons.photo_camera_front_outlined,
                label: 'Try-on portrait',
                value: p?.tryOnPhotoUrl == null ? 'Add one' : 'Change',
                onTap: _changePortrait,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            title: 'Privacy',
            children: [
              const _Row(icon: Icons.lock_outline_rounded, label: 'Your photos', value: 'Private to your account'),
              _Row(
                icon: Icons.delete_outline_rounded,
                label: _deleting ? 'Deleting…' : 'Delete account & photos',
                destructive: true,
                onTap: _deleting ? null : _deleteAccount,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const PipSceneCard(PipScene.relaxing, height: 170, caption: 'Take it easy — I’ve got your closet pinned 💕'),
          const SizedBox(height: 16),
          VastraSecondaryButton(label: 'Sign out', icon: Icons.logout_rounded, onPressed: () => auth.signOut()),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Vastra · with Pip 📍 · try-on by YouCam · styling by Gemini',
              style: GoogleFonts.outfit(fontSize: 12, color: VastraColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              letterSpacing: 1.2,
              color: VastraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        VastraSurface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56, color: VastraColors.border),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.value, this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? VastraColors.danger : VastraColors.charcoal;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: destructive ? VastraColors.danger : VastraColors.chocolate),
      title: Text(
        label,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: color),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value!,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 13, color: VastraColors.muted),
              ),
            ),
          if (onTap != null && !destructive) const Icon(Icons.chevron_right_rounded, color: VastraColors.muted),
        ],
      ),
    );
  }
}
