import 'package:flutter/cupertino.dart';

import 'app.dart';
import 'design/theme.dart';
import 'screens/login_screen.dart';
import 'screens/vet/vet_shell.dart';
import 'state/app_store.dart';

/// Vet flavor entry point.
///
/// Build it with the vet flavor's Dart entry:
///
///   Android: flutter build apk --flavor vet --target lib/main_vet.dart
///            --dart-define=APP_FLAVOR=vet
///   iOS:     the `vet` scheme (ios/Runner.xcodeproj) bakes the entry point
///            into ios/Flutter/Vet.xcconfig; add --dart-define=APP_FLAVOR=vet
///
/// This file is the ONLY place outside lib/screens/vet/ that references vet
/// screens. lib/main.dart and lib/app.dart must stay vet-free so the
/// customer build tree-shakes the portal out.
///
/// Auth decides the shell: launch → login → [postAuthShell]. Registering
/// [vetShellFactory] here is what lets the shared router resolve a staff
/// sign-in to [VetShell]. A customer credential in this binary still signs
/// in but lands on the customer [RootShell] — vet UI simply does not render
/// for it (pinned by test/vet_entry_test.dart). The factory never grants
/// access; the role does.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  // Awaited before the first frame so the app never flashes the warm light
  // palette at someone whose saved choice is dark.
  await store.loadSettings();
  // What makes this binary the vet flavor. Registered before the first
  // frame so a restored vet session boots straight into the portal.
  vetShellFactory = () => const VetShell();
  // Drives the queue/schedule time partitions — and the customer shell's
  // live countdowns, for a customer credential in this binary.
  store.startClock();
  runApp(_VetApp(store: store));
}

/// iOS-first, like the customer app: CupertinoApp navigation and the system
/// (SF Pro) text theme.
class _VetApp extends StatefulWidget {
  const _VetApp({required this.store});

  final AppStore store;

  @override
  State<_VetApp> createState() => _VetAppState();
}

class _VetAppState extends State<_VetApp> {
  @override
  void initState() {
    super.initState();
    // The app root owns the CupertinoTheme, so it has to rebuild when the
    // appearance changes — AppScope sits below CupertinoApp and cannot drive
    // it. Same recipe as the customer entry point.
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  /// Resolves [AppStore.themeMode] into a palette. `system` reads the
  /// platform brightness directly: it has to be answered above [CupertinoApp],
  /// where there is no MediaQuery yet.
  AppPalette get _palette {
    final store = widget.store;
    return switch (store.themeMode) {
      ThemeMode.dark => AppPalette.dark,
      ThemeMode.light => AppPalette.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark
            ? AppPalette.dark
            : AppPalette.light,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: widget.store,
      child: CupertinoApp(
        title: 'CarePaws Vet',
        debugShowCheckedModeBanner: false,
        theme: themeFor(_palette),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // Honour the system text scale, but keep the app usable when the
            // platform reports an extreme value.
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 3.2,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: VetLaunch(store: widget.store),
      ),
    );
  }
}

/// Launch routing for the vet flavor.
///
/// A restored session skips login and lands straight on the post-auth shell;
/// signed out, the shared login screen shows. On sign-in the router picks
/// the shell by role ([postAuthShell]): staff → [VetShell], customer → the
/// customer [RootShell].
///
/// Staff accounts are provisioned, so the customer onboarding tour (pet
/// setup) is skipped in this binary — staff get the login screen, not a
/// tour of customer features.
class VetLaunch extends StatelessWidget {
  const VetLaunch({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (store.signedIn) return postAuthShell(store);
    return LoginScreen(
      onSignedIn: () {
        // Unwind the login screen: Back from the shell must exit the app,
        // not land back on a signed-in login form.
        Navigator.of(context)
            .pushAndRemoveUntil(appRoute(postAuthShell(store)), (_) => false);
      },
    );
  }
}
