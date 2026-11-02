import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/picked_photo.dart';
import 'vastra_widgets.dart';

final _picker = ImagePicker();

Future<List<PickedPhoto>> _read(List<XFile> files) => Future.wait(files.map(PickedPhoto.fromXFile));

void _permissionHint(BuildContext context, String what) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Vastra needs access to your $what — you can allow it in Settings.')));
}

/// Opens the photo library straight away (no camera/library sheet).
Future<List<PickedPhoto>> pickFromLibrary(BuildContext context, {bool multiple = false}) async {
  try {
    if (multiple) {
      return await _read(await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600, limit: 20));
    }
    final shot = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    return shot == null ? const [] : await _read([shot]);
  } catch (_) {
    if (context.mounted) _permissionHint(context, 'photos');
    return const [];
  }
}

/// Asks camera vs library, then returns the chosen photos (max 1600px).
Future<List<PickedPhoto>> pickPhotos(
  BuildContext context, {
  required String title,
  String? subtitle,
  bool multiple = false,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VastraHeading(title, subtitle: subtitle, size: 28),
            const SizedBox(height: 18),
            VastraPrimaryButton(
              label: 'Take a photo',
              icon: Icons.photo_camera_outlined,
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            VastraSecondaryButton(
              label: multiple ? 'Choose from library' : 'Choose a photo',
              icon: Icons.photo_library_outlined,
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return const [];
  if (source == ImageSource.gallery) return pickFromLibrary(context, multiple: multiple);
  return pickFromCamera(context);
}

/// Opens the camera straight away (no camera/library sheet).
Future<List<PickedPhoto>> pickFromCamera(BuildContext context) async {
  try {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
      preferredCameraDevice: kIsWeb ? CameraDevice.front : CameraDevice.rear,
    );
    return shot == null ? const [] : await _read([shot]);
  } catch (_) {
    if (context.mounted) _permissionHint(context, 'camera');
    return const [];
  }
}
