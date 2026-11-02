import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'firebase_options.dart';
import 'providers/auth_controller.dart';
import 'providers/today_controller.dart';
import 'providers/try_on_request.dart';
import 'theme/vastra_theme.dart';
import 'widgets/app_frame.dart';
import 'widgets/connection_banner.dart';
import 'widgets/phone_behavior.dart';
import 'widgets/pip.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Keep a local copy of the closet, profile and looks so returning visits paint instantly and work offline.
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: kIsWeb ? WebPersistentMultipleTabManager() : null,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  // Fonts ship with the app (assets/google_fonts); waiting briefly avoids a visible font swap on first paint.
  GoogleFonts.config.allowRuntimeFetching = true;
  await GoogleFonts.pendingFonts([
    GoogleFonts.outfit(),
    GoogleFonts.outfit(fontWeight: FontWeight.w500),
    GoogleFonts.outfit(fontWeight: FontWeight.w600),
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600),
  ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
  // On the web, fallback fonts (e.g. emoji) download on first use. Text laid out before they arrive gets
  // repainted but not always re-measured, which clips labels like the occasion chips; re-measure everything.
  if (kIsWeb) PaintingBinding.instance.systemFonts.addListener(_remeasureAfterFontLoad);
  // In release, a widget that fails to build shows a quiet note instead of a grey box.
  if (kReleaseMode) ErrorWidget.builder = (_) => const _QuietError();
  runApp(const VastraApp());
}

class VastraApp extends StatefulWidget {
  const VastraApp({super.key});

  @override
  State<VastraApp> createState() => _VastraAppState();
}

class _VastraAppState extends State<VastraApp> {
  late final AuthController _auth = AuthController();
  late final TodayController _today = TodayController();
  late final TryOnRequest _tryOnRequest = TryOnRequest();
  late final GoRouter _router = createRouter(_auth);

  @override
  void dispose() {
    _auth.dispose();
    _today.dispose();
    _tryOnRequest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _today),
        ChangeNotifierProvider.value(value: _tryOnRequest),
      ],
      child: MaterialApp.router(
        title: 'Vastra',
        debugShowCheckedModeBanner: false,
        theme: phoneTheme(VastraTheme.light),
        scrollBehavior: const PhoneScrollBehavior(),
        routerConfig: _router,
        builder: (context, child) => AppFrame(
          child: _PipPreloader(child: ConnectionBanner(child: child ?? const SizedBox.shrink())),
        ),
      ),
    );
  }
}

/// Warms Pip's artwork once so she never pops in blank.
class _PipPreloader extends StatefulWidget {
  const _PipPreloader({required this.child});
  final Widget child;

  @override
  State<_PipPreloader> createState() => _PipPreloaderState();
}

class _PipPreloaderState extends State<_PipPreloader> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    precachePip(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _QuietError extends StatelessWidget {
  const _QuietError();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'This bit didn’t load — pull down or reopen to try again.',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: TextStyle(color: Color(0xFF8F8276), fontSize: 13),
      ),
    ),
  );
}

void _remeasureAfterFontLoad() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    void visit(RenderObject node) {
      node.markNeedsLayout();
      node.visitChildren(visit);
    }

    for (final view in RendererBinding.instance.renderViews) {
      visit(view);
    }
  });
  WidgetsBinding.instance.scheduleFrame();
}
