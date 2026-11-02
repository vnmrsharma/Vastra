import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/picked_photo.dart';

/// Something handed to the Try on tab: a closet piece or any outfit photo.
class TryOnHandoff {
  const TryOnHandoff.item(this.itemId) : photo = null, category = null;
  const TryOnHandoff.photo(this.photo, {this.category = 'full_body'}) : itemId = null;

  final String? itemId;
  final PickedPhoto? photo;
  final String? category;
}

/// Lets any screen hand a closet piece or photo to the Try on tab, whether or
/// not that tab has been opened before.
class TryOnRequest extends ChangeNotifier {
  TryOnHandoff? _pending;

  bool get hasPending => _pending != null;

  void request(String itemId) {
    _pending = TryOnHandoff.item(itemId);
    notifyListeners();
  }

  void requestPhoto(PickedPhoto photo, {String category = 'full_body'}) {
    _pending = TryOnHandoff.photo(photo, category: category);
    notifyListeners();
  }

  TryOnHandoff? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}

/// Selects [itemId] in the Try on tab and switches to it.
void openTryOn(BuildContext context, String itemId) {
  context.read<TryOnRequest>().request(itemId);
  context.go('/app/try-on');
}

/// Opens the Try on tab with any outfit photo (YouCam swaps the whole look by default).
void openTryOnWithPhoto(BuildContext context, PickedPhoto photo, {String category = 'full_body'}) {
  context.read<TryOnRequest>().requestPhoto(photo, category: category);
  context.go('/app/try-on');
}
