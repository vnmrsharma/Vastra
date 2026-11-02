import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/picked_photo.dart';
import '../../services/wardrobe_service.dart';
import '../../widgets/phone_behavior.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/vastra_widgets.dart';

enum _ShotState { uploading, saved, failed }

class _Shot {
  _Shot(this.photo);
  final PickedPhoto photo;
  _ShotState state = _ShotState.uploading;
}

/// Full-screen camera for filling the closet: every tap of the shutter saves a
/// piece immediately and the camera stays open for the next one.
class SnapCameraScreen extends StatefulWidget {
  const SnapCameraScreen({super.key, required this.uid});

  final String uid;

  /// Opens the camera and returns how many pieces were saved.
  static Future<int> open(BuildContext context, String uid) async {
    final saved = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<int>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SnapCameraScreen(uid: uid)));
    return saved ?? 0;
  }

  @override
  State<SnapCameraScreen> createState() => _SnapCameraScreenState();
}

class _SnapCameraScreenState extends State<SnapCameraScreen> with WidgetsBindingObserver {
  final _wardrobe = WardrobeService();
  final List<_Shot> _shots = [];

  CameraController? _controller;
  bool _initializing = true;
  String? _cameraError;
  bool _capturing = false;
  bool _flash = false;
  FlashMode _flashMode = FlashMode.off;

  int get _savedCount => _shots.where((s) => s.state == _ShotState.saved).length;
  int get _uploadingCount => _shots.where((s) => s.state == _ShotState.uploading).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    frameStatusBarLight.value = true;
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    frameStatusBarLight.value = false;
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'No camera on this device');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!kIsWeb) {
        try {
          await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
          await controller.setFlashMode(_flashMode);
        } catch (_) {}
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(() {
        _cameraError = e.code.contains('Denied') || e.code.contains('Restricted')
            ? 'Vastra needs camera access. Turn it on in Settings → Vastra → Camera.'
            : e.code == 'NoCamera'
            ? 'No camera here — add photos from your library instead.'
            : 'The camera couldn’t start. Try again or use your library.';
      });
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _snap() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() {
      _capturing = true;
      _flash = true;
    });
    HapticFeedback.mediumImpact();
    try {
      final picture = await controller.takePicture();
      final shot = _Shot(await PickedPhoto.fromXFile(picture));
      setState(() => _shots.insert(0, shot));
      _upload(shot);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That snap didn’t work — try again.')));
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
        Future.delayed(const Duration(milliseconds: 160), () {
          if (mounted) setState(() => _flash = false);
        });
      }
    }
  }

  Future<void> _upload(_Shot shot) async {
    setState(() => shot.state = _ShotState.uploading);
    try {
      await _wardrobe.addFromPhoto(uid: widget.uid, photo: shot.photo);
      if (mounted) setState(() => shot.state = _ShotState.saved);
    } catch (_) {
      if (mounted) setState(() => shot.state = _ShotState.failed);
    }
  }

  Future<void> _fromLibrary() async {
    final files = await pickFromLibrary(context, multiple: true);
    if (files.isEmpty || !mounted) return;
    final shots = files.map(_Shot.new).toList();
    setState(() => _shots.insertAll(0, shots));
    for (final shot in shots) {
      _upload(shot);
    }
  }

  Future<void> _toggleFlash() async {
    final next = _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
    setState(() => _flashMode = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {}
  }

  void _done() => Navigator.of(context).pop(_savedCount + _uploadingCount);

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                saved: _savedCount,
                uploading: _uploadingCount,
                flashOn: _flashMode != FlashMode.off,
                showFlash: ready && !kIsWeb,
                onClose: _done,
                onFlash: _toggleFlash,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ready)
                          TapTarget(
                            onTap: _snap,
                            child: _CoverPreview(controller: controller),
                          )
                        else
                          _CameraPlaceholder(
                            loading: _initializing,
                            message: _cameraError,
                            onRetry: _initCamera,
                            onLibrary: _fromLibrary,
                          ),
                        if (ready && !kIsWeb) const _FrameGuide(),
                        IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _flash ? 0.7 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: Container(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_shots.isNotEmpty) _ShotStrip(shots: _shots, onRetry: _upload),
              _Controls(
                ready: ready,
                capturing: _capturing,
                count: _shots.length,
                onSnap: _snap,
                onLibrary: _fromLibrary,
                onDone: _done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (kIsWeb) {
      // Browsers report the stream already oriented and render it with object-fit: cover, so match its real
      // aspect ratio instead of swapping sides (which crops a landscape webcam into a narrow, zoomed strip).
      final ratio = size == null || size.height == 0 ? controller.value.aspectRatio : size.width / size.height;
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(fit: StackFit.expand, children: [controller.buildPreview(), const _FrameGuide()]),
          ),
        ),
      );
    }
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: size.height, height: size.width, child: CameraPreview(controller)),
    );
  }
}

class _FrameGuide extends StatelessWidget {
  const _FrameGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.78,
              heightFactor: 0.72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'One piece at a time · tap anywhere to snap',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.saved,
    required this.uploading,
    required this.flashOn,
    required this.showFlash,
    required this.onClose,
    required this.onFlash,
  });

  final int saved;
  final int uploading;
  final bool flashOn;
  final bool showFlash;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    final label = saved == 0 && uploading == 0
        ? 'Snap your clothes'
        : uploading > 0
        ? '$saved saved · $uploading saving…'
        : '$saved saved to your closet';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
          SizedBox(
            width: 48,
            child: showFlash
                ? IconButton(
                    onPressed: onFlash,
                    icon: Icon(flashOn ? Icons.flash_auto_rounded : Icons.flash_off_rounded, color: Colors.white),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({
    required this.loading,
    required this.message,
    required this.onRetry,
    required this.onLibrary,
  });

  final bool loading;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1816),
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator(color: Colors.white)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 44),
                const SizedBox(height: 14),
                Text(
                  message ?? 'Camera unavailable',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onLibrary,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Add from library'),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Try camera again', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
    );
  }
}

class _ShotStrip extends StatelessWidget {
  const _ShotStrip({required this.shots, required this.onRetry});

  final List<_Shot> shots;
  final ValueChanged<_Shot> onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: shots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final shot = shots[i];
          return TapTarget(
            onTap: shot.state == _ShotState.failed ? () => onRetry(shot) : null,
            child: SizedBox(
              width: 50,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(shot.photo.bytes, fit: BoxFit.cover, cacheWidth: 160, gaplessPlayback: true),
                  ),
                  Positioned(right: -2, bottom: -2, child: _StatusDot(state: shot.state)),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),
          );
        },
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.state});
  final _ShotState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      _ShotState.uploading => (VastraColors.chocolate, null),
      _ShotState.saved => (VastraColors.success, Icons.check_rounded),
      _ShotState.failed => (VastraColors.danger, Icons.refresh_rounded),
    };
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: icon == null
          ? const Padding(
              padding: EdgeInsets.all(4),
              child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white),
            )
          : Icon(icon, size: 12, color: Colors.white),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.ready,
    required this.capturing,
    required this.count,
    required this.onSnap,
    required this.onLibrary,
    required this.onDone,
  });

  final bool ready;
  final bool capturing;
  final int count;
  final VoidCallback onSnap;
  final VoidCallback onLibrary;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: IconButton(
              onPressed: onLibrary,
              tooltip: 'Add from library',
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
            ),
          ),
          Expanded(
            child: Center(
              child: TapTarget(
                onTap: ready ? onSnap : null,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: capturing ? 0.88 : 1,
                  child: Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ready ? Colors.white : Colors.white24, width: 4),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ready ? VastraColors.blush : Colors.white24,
                      ),
                      child: const Icon(Icons.checkroom_rounded, color: VastraColors.burgundy),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: count == 0
                ? null
                : FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: VastraColors.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    child: const Text('Done'),
                  ),
          ),
        ],
      ),
    );
  }
}
