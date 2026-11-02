List<String> _strings(dynamic value) => value is List ? value.whereType<String>().toList() : const [];

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.onboardingComplete,
    this.onboardingStep = 0,
    this.tryOnPhotoPath,
    this.tryOnPhotoUrl,
    this.tryOnCutoutUrl,
    this.tryOnCutoutFor,
    this.preferredCity,
    this.styleNotes,
    this.genderPresentation,
    this.vibes = const [],
    this.favouriteColours = const [],
    this.occasions = const [],
  });

  final String uid;
  final String email;
  final String displayName;
  final int createdAt;
  final bool onboardingComplete;
  final int onboardingStep;
  final String? tryOnPhotoPath;
  final String? tryOnPhotoUrl;
  final String? tryOnCutoutUrl;
  final String? tryOnCutoutFor;

  /// Background-free portrait, if it matches the current try-on photo.
  String? get portraitCutoutUrl => tryOnCutoutFor != null && tryOnCutoutFor == tryOnPhotoPath ? tryOnCutoutUrl : null;
  final String? preferredCity;
  final String? styleNotes;
  final String? genderPresentation;
  final List<String> vibes;
  final List<String> favouriteColours;
  final List<String> occasions;

  String get firstName {
    final name = displayName.trim();
    return name.isEmpty ? 'there' : name.split(' ').first;
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      createdAt: data['createdAt'] as int? ?? 0,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      onboardingStep: data['onboardingStep'] as int? ?? 0,
      tryOnPhotoPath: data['tryOnPhotoPath'] as String?,
      tryOnPhotoUrl: data['tryOnPhotoUrl'] as String?,
      tryOnCutoutUrl: data['tryOnCutoutUrl'] as String?,
      tryOnCutoutFor: data['tryOnCutoutFor'] as String?,
      preferredCity: data['preferredCity'] as String?,
      styleNotes: data['styleNotes'] as String?,
      genderPresentation: data['genderPresentation'] as String?,
      vibes: _strings(data['vibes']),
      favouriteColours: _strings(data['favouriteColours']),
      occasions: _strings(data['occasions']),
    );
  }
}

class WardrobeItem {
  WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.colour,
    required this.imagePath,
    required this.imageUrl,
    required this.createdAt,
    this.tagging = false,
    this.pattern,
    this.wearCount = 0,
    this.lastWornAt,
    this.cutoutUrl,
    this.cutoutPath,
    this.cutoutThumbUrl,
    this.cutoutThumbPath,
    this.cutoutStatus,
  });

  final String id;
  final String name;
  final String category;
  final String colour;
  final String imagePath;
  final String imageUrl;
  final int createdAt;
  final bool tagging;
  final String? pattern;
  final int wearCount;
  final int? lastWornAt;
  final String? cutoutUrl;
  final String? cutoutPath;
  final String? cutoutThumbUrl;
  final String? cutoutThumbPath;
  final String? cutoutStatus;

  /// Small cutout for grids and rails; falls back to the full cutout.
  String? get tileCutoutUrl => cutoutThumbUrl ?? cutoutUrl;

  /// No cutout yet, or one made before cutouts were optimised (re-encoding costs no YouCam units).
  bool get needsCutout =>
      imagePath.isNotEmpty &&
      ((cutoutUrl == null && cutoutStatus == null) ||
          (cutoutUrl != null && cutoutStatus == 'done' && cutoutThumbUrl == null));

  /// YouCam garment category that best matches this closet category.
  String get garmentCategory => garmentCategoryFor(category);

  /// Days since last worn, or null if never worn.
  int? get daysSinceWorn =>
      lastWornAt == null ? null : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastWornAt!)).inDays;

  String get wearLabel {
    if (wearCount == 0) return 'Not worn yet';
    final days = daysSinceWorn ?? 0;
    final when = days == 0
        ? 'today'
        : days == 1
        ? 'yesterday'
        : '$days days ago';
    return 'Worn $wearCount× · last $when';
  }

  factory WardrobeItem.fromDoc(String id, Map<String, dynamic> data) {
    return WardrobeItem(
      id: id,
      name: data['name'] as String? ?? 'New piece',
      category: data['category'] as String? ?? 'tops',
      colour: data['colour'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      createdAt: data['createdAt'] as int? ?? 0,
      tagging: data['tagging'] as bool? ?? false,
      pattern: data['pattern'] as String?,
      wearCount: (data['wearCount'] as num?)?.toInt() ?? 0,
      lastWornAt: (data['lastWornAt'] as num?)?.toInt(),
      cutoutUrl: data['cutoutFor'] != null && data['cutoutFor'] == data['imagePath']
          ? data['cutoutUrl'] as String?
          : null,
      cutoutPath: data['cutoutPath'] as String?,
      cutoutThumbUrl: data['cutoutFor'] != null && data['cutoutFor'] == data['imagePath']
          ? data['cutoutThumbUrl'] as String?
          : null,
      cutoutThumbPath: data['cutoutThumbPath'] as String?,
      cutoutStatus: data['cutoutStatus'] as String?,
    );
  }
}

class WornToday {
  WornToday({required this.title, required this.occasion, required this.itemIds});

  final String title;
  final String occasion;
  final List<String> itemIds;

  factory WornToday.fromMap(Map<String, dynamic> data) => WornToday(
    title: data['title'] as String? ?? 'Today’s outfit',
    occasion: data['occasion'] as String? ?? '',
    itemIds: _strings(data['itemIds']),
  );
}

class TryOnJob {
  TryOnJob({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.resultUrl,
    this.garmentImageUrl,
    this.errorCode,
    this.favourite = false,
    this.kind,
    this.step = 0,
    this.steps = 0,
    this.stepLabel,
    this.resultCutoutUrl,
    this.wardrobeItemIds = const [],
  });

  final String id;
  final String title;
  final String status;
  final int createdAt;
  final String? resultUrl;
  final String? garmentImageUrl;
  final String? errorCode;
  final bool favourite;
  final String? kind;
  final int step;
  final int steps;
  final String? stepLabel;
  final String? resultCutoutUrl;
  final List<String> wardrobeItemIds;

  bool get isSuccess => status == 'success' && resultUrl != null;

  factory TryOnJob.fromDoc(String id, Map<String, dynamic> data) {
    return TryOnJob(
      id: id,
      title: data['title'] as String? ?? 'Try-on',
      status: data['status'] as String? ?? 'processing',
      createdAt: data['createdAt'] as int? ?? 0,
      resultUrl: data['resultUrl'] as String?,
      garmentImageUrl: data['garmentImageUrl'] as String?,
      errorCode: data['errorCode'] as String?,
      favourite: data['favourite'] as bool? ?? false,
      kind: data['kind'] as String?,
      step: (data['step'] as num?)?.toInt() ?? 0,
      steps: (data['steps'] as num?)?.toInt() ?? 0,
      stepLabel: data['stepLabel'] as String?,
      resultCutoutUrl: data['resultCutoutUrl'] as String?,
      wardrobeItemIds: (data['wardrobeItemIds'] as List? ?? const []).whereType<String>().toList(),
    );
  }
}

class WeatherSnapshot {
  WeatherSnapshot({
    required this.location,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.description,
    required this.precipMm,
  });

  final String location;
  final num temperatureC;
  final num feelsLikeC;
  final String description;
  final num precipMm;

  factory WeatherSnapshot.fromMap(Map<String, dynamic> data) {
    return WeatherSnapshot(
      location: data['location'] as String? ?? '',
      temperatureC: data['temperatureC'] as num? ?? 0,
      feelsLikeC: data['feelsLikeC'] as num? ?? 0,
      description: data['description'] as String? ?? '',
      precipMm: data['precipMm'] as num? ?? 0,
    );
  }
}

class LookItem {
  LookItem({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl,
    this.cutoutUrl,
    this.cutoutThumbUrl,
  });

  final String id;
  final String name;
  final String category;
  final String? imageUrl;
  final String? cutoutUrl;
  final String? cutoutThumbUrl;

  String? get tileCutoutUrl => cutoutThumbUrl ?? cutoutUrl;

  factory LookItem.fromMap(Map<String, dynamic> m) => LookItem(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    category: m['category'] as String? ?? '',
    imageUrl: m['imageUrl'] as String?,
    cutoutUrl: m['cutoutUrl'] as String?,
    cutoutThumbUrl: m['cutoutThumbUrl'] as String?,
  );
}

class OutfitSuggestion {
  OutfitSuggestion({required this.title, required this.reason, required this.items});

  final String title;
  final String reason;
  final List<LookItem> items;
}

const wardrobeCategories = ['tops', 'trousers', 'skirts', 'dresses', 'outerwear', 'shoes', 'bags', 'accessories'];

const occasions = ['work', 'casual', 'date', 'formal', 'sport', 'travel'];

const garmentCategories = ['full_body', 'upper_body', 'lower_body', 'outer', 'shoes', 'auto'];

/// Aesthetic → emoji. Stored on the profile as `vibes` (plain names).
const aesthetics = {
  'Cottagecore': '🌼',
  'Minimal': '🤍',
  'Streetwear': '🛹',
  'Grunge': '🖤',
  'Old money': '🏛️',
  'Y2K': '💿',
  'Boho': '🌾',
  'Dark academia': '📚',
  'Coastal': '🌊',
  'Coquette': '🎀',
  'Preppy': '🎓',
  'Athleisure': '🧘',
  'Gorpcore': '🥾',
  'Clean girl': '✨',
  'Romantic': '🌸',
  'Edgy': '⚡',
};

const presentations = {
  'feminine': 'Feminine',
  'masculine': 'Masculine',
  'androgynous': 'Androgynous',
  'prefer_not': 'Prefer not to say',
};

/// Colour name → swatch value used for the "colours you love" picker.
const colourSwatches = {
  'Black': 0xFF1F1B18,
  'White': 0xFFFAF8F3,
  'Cream': 0xFFF1E6D0,
  'Beige': 0xFFD9C3A5,
  'Brown': 0xFF7A5238,
  'Grey': 0xFF9C9690,
  'Navy': 0xFF253552,
  'Blue': 0xFF5B84B1,
  'Green': 0xFF6E8B67,
  'Olive': 0xFF7D7A45,
  'Red': 0xFFB23A3A,
  'Burgundy': 0xFF7A2E3B,
  'Pink': 0xFFE7A9B5,
  'Lilac': 0xFFB9A6D1,
  'Yellow': 0xFFE9C85A,
  'Orange': 0xFFE08A4B,
};

String garmentCategoryFor(String wardrobeCategory) =>
    const {
      'tops': 'upper_body',
      'trousers': 'lower_body',
      'skirts': 'lower_body',
      'dresses': 'full_body',
      'outerwear': 'outer',
      'shoes': 'shoes',
    }[wardrobeCategory] ??
    'auto';

String categoryLabel(String value) =>
    const {
      'tops': 'Tops',
      'trousers': 'Trousers',
      'skirts': 'Skirts',
      'dresses': 'Dresses',
      'outerwear': 'Outerwear',
      'shoes': 'Shoes',
      'bags': 'Bags',
      'accessories': 'Accessories',
    }[value] ??
    value;

String occasionLabel(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String garmentLabel(String value) =>
    const {
      'full_body': 'Full outfit',
      'upper_body': 'Top',
      'lower_body': 'Bottoms',
      'outer': 'Outerwear',
      'shoes': 'Shoes',
      'auto': 'Let AI decide',
    }[value] ??
    value;

const occasionIcons = {'work': '💼', 'casual': '☕', 'date': '🌹', 'formal': '✨', 'sport': '🏃', 'travel': '✈️'};

/// Plain-English explanations for YouCam error codes.
String explainTryOnError(String? code) {
  switch (code) {
    case 'error_pose':
      return 'YouCam couldn’t read your pose. Use a portrait standing straight, facing the camera.';
    case 'error_multi_person':
      return 'There seem to be a few people in the photo — try one with just you.';
    case 'error_invalid_ref':
      return 'That garment photo didn’t work. Use a clear, front-facing shot of one piece.';
    case 'error_apply_region_mismatch':
      return 'The garment didn’t match the chosen type — try “Let AI decide”.';
    case 'error_invalid_src':
      return 'Your portrait needs to show your upper body and face clearly.';
    case 'error_nsfw_content_detected':
      return 'YouCam couldn’t use this result. Try a different garment.';
    case 'error_editing_failed':
      return 'The result looked identical to your photo — try a more distinct garment.';
    case 'timeout':
      return 'YouCam is extra busy right now — give it another go in a minute.';
    case 'task_expired':
      return 'That try-on took too long and expired. Please try again.';
    default:
      return code == null || code.isEmpty
          ? 'YouCam couldn’t finish this one. Try another photo.'
          : 'YouCam couldn’t finish this one ($code). Try another photo.';
  }
}

/// One garment from an inspiration photo and the closest piece in the closet.
class RecreatePiece {
  RecreatePiece({required this.piece, required this.category, required this.closeness, required this.note, this.item});

  final String piece;
  final String category;
  final String closeness; // exact | close | swap | missing
  final String note;
  final LookItem? item;

  factory RecreatePiece.fromMap(Map<String, dynamic> m) {
    final item = m['item'] is Map ? Map<String, dynamic>.from(m['item'] as Map) : null;
    return RecreatePiece(
      piece: m['piece'] as String? ?? '',
      category: m['category'] as String? ?? '',
      closeness: m['closeness'] as String? ?? 'missing',
      note: m['note'] as String? ?? '',
      item: item == null ? null : LookItem.fromMap(item),
    );
  }
}

/// "Recreate a look" result: how close the closet gets to an outfit photo.
class RecreateResult {
  RecreateResult({
    required this.id,
    required this.title,
    required this.vibe,
    required this.summary,
    required this.tip,
    required this.score,
    required this.pieces,
    required this.createdAt,
    this.imageUrl,
    this.imagePath,
  });

  final String id;
  final String title;
  final String vibe;
  final String summary;
  final String tip;
  final int score;
  final List<RecreatePiece> pieces;
  final int createdAt;
  final String? imageUrl;
  final String? imagePath;

  List<LookItem> get matchedItems => pieces.map((p) => p.item).whereType<LookItem>().toList();

  factory RecreateResult.fromMap(String id, Map<String, dynamic> m) => RecreateResult(
    id: id,
    title: m['title'] as String? ?? 'Your look',
    vibe: m['vibe'] as String? ?? '',
    summary: m['summary'] as String? ?? '',
    tip: m['tip'] as String? ?? '',
    score: (m['score'] as num?)?.toInt() ?? 0,
    pieces: (m['pieces'] as List? ?? [])
        .whereType<Map>()
        .map((p) => RecreatePiece.fromMap(Map<String, dynamic>.from(p)))
        .toList(),
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    imageUrl: m['imageUrl'] as String?,
    imagePath: m['imagePath'] as String?,
  );
}
