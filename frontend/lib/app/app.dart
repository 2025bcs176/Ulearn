import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_splash_screen/flutter_splash_screen.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/theme/app_theme.dart';

/// The application root.
///
/// Holds nothing but wiring: theme, router, and the providers the router needs
/// in order to make a redirect decision. Keeping it free of feature logic means
/// the shell can be replaced or removed without touching a feature.
class PeerPassApp extends ConsumerStatefulWidget {
  const PeerPassApp({super.key});

  @override
  ConsumerState<PeerPassApp> createState() => _PeerPassAppState();
}

class _PeerPassAppState extends ConsumerState<PeerPassApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        unawaited(FlutterSplashScreen.hide());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PeerPass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
