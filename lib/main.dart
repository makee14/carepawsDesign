import 'package:flutter/cupertino.dart';

import 'app.dart';
import 'design/theme.dart';
import 'screens/add_pet_screen.dart';
import 'screens/appointments/book_flow.dart';
import 'screens/appointments_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/edit_pet_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/chat_thread_screen.dart';
import 'screens/pets/pet_profile_screen.dart';
import 'screens/profile/about_screen.dart';
import 'screens/profile/privacy_screen.dart';
import 'screens/profile/settings_screens.dart';
import 'screens/profile_screen.dart';
import 'screens/shops_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/shop/cart_screen.dart';
import 'screens/shop/checkout_screen.dart';
import 'screens/shop/order_success_screen.dart';
import 'screens/shop/orders_screen.dart';
import 'screens/shop/product_detail_screen.dart';
import 'screens/triage_screen.dart';

import 'state/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  // Awaited before the first frame so the app never flashes the warm light
  // palette at someone whose saved choice is dark. SettingsStore swallows plugin
  // failures, so this cannot hold up the launch.
  await store.loadSettings();
  runApp(PetCareApp(store: store));
}

/// Visual-review harness. Set a `--dart-define=SHOT=<screen>` to boot straight
/// into one screen, e.g.
///
///   flutter run -d linux --dart-define=SHOT=triage
///
/// Never enabled in a normal build.
const String _shot = String.fromEnvironment('SHOT');

/// iOS-first: CupertinoApp navigation, Cupertino sheet/alert patterns and the
/// system (SF Pro) text theme. Android still runs — it just renders the same
/// Cupertino widgets.
class PetCareApp extends StatefulWidget {
  const PetCareApp({super.key, required this.store, this.skipSplash = false});

  final AppStore store;

  /// Tests and screenshots jump straight to the tab shell.
  final bool skipSplash;

  @override
  State<PetCareApp> createState() => _PetCareAppState();
}

class _PetCareAppState extends State<PetCareApp> with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // The palette used to be hardcoded to AppPalette.light, so switching
    // Appearance → Dark updated the store and changed nothing on screen. The
    // app root owns the CupertinoTheme, so it has to rebuild when the
    // appearance changes — AppScope sits below CupertinoApp and cannot drive it.
    widget.store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(PetCareApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.store, widget.store)) return;
    oldWidget.store.removeListener(_onStoreChanged);
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // System appearance changed while in Automatic mode — repaint.
    if (mounted) setState(() {});
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  /// Resolves [AppStore.themeMode] into a palette. `system` reads the platform
  /// brightness directly: it has to be answered above [CupertinoApp], where
  /// there is no MediaQuery yet.
  AppPalette get _palette {
    final store = widget.store;
    return switch (store.themeMode) {
      ThemeMode.dark => AppPalette.dark,
      ThemeMode.light => AppPalette.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light,
    };
  }

  Future<void> _goToShell() async {
    final nav = _navKey.currentState;
    if (nav == null) {
      setState(() {});
      return;
    }
    await nav.pushReplacement(appRoute(const RootShell()));
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: widget.store,
      child: CupertinoApp(
        navigatorKey: _navKey,
        title: 'PetCare',
        debugShowCheckedModeBanner: false,
        theme: themeFor(_palette),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // Honour the system text scale, but keep the app usable when the
            // platform reports an extreme value.
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 3.2),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: widget.skipSplash
            ? const RootShell()
            : _shot.isEmpty
            ? SplashScreen(onDone: _goToShell)
            : const _ShotHost(),
      ),
    );
  }
}

/// Test helper: a store with a deterministic clock.
AppStore demoStore({DateTime? now}) => AppStore(now: now);
/// Routes to a single screen for visual review / screenshots.
class _ShotHost extends StatefulWidget {
  const _ShotHost();

  @override
  State<_ShotHost> createState() => _ShotHostState();
}

class _ShotHostState extends State<_ShotHost> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = _shot;
    final Widget screen = switch (s) {
      'pet' => const PetProfileScreen(petId: 'p1'),
      'triage' => const TriageScreen(),
      'book' => const BookFlow(),
      'product' => const ProductDetailScreen(productId: 'pr1'),
      'cart' => const CartScreen(),
      'checkout' => const CheckoutScreen(),
      'orders' => const OrdersScreen(),
      'order' => const OrderSuccessScreen(orderId: 'o1'),
      'ai' => const ChatThreadScreen(threadId: 'th_ai'),
      'clinic' => const ChatThreadScreen(threadId: 'th_clinic'),
      'profile' => const ProfileScreen(),
      'settings' => const SettingsScreen(),
      'privacy' => const PrivacyScreen(),
      'about' => const AboutScreen(),
      'faq' => const FaqScreen(),
      'reminders' => const RemindersScreen(),
      'clinicinfo' => const ClinicInfoScreen(),
      'addpet' => const AddPetScreen(),
      'editpet' => const EditPetScreen(petId: 'p1'),
      'editprofile' => const EditProfileScreen(),
      'aisettings' => const AiSettingsScreen(),
      'login' => LoginScreen(onSignedIn: _noop),
      'splash' => const SplashScreen(onDone: _noop),
      _ => const RootShell(),
    };

    // Seed the cart so checkout / order screens have something to show.
    if (s == 'cart' || s == 'checkout' || s == 'order') {
      store.addToCart('pr1');
      store.addToCart('pr3', 2);
    }

    if (s == 'home' || s == '') {
      return _Tabbed(initial: _tab, onTab: (i) => setState(() => _tab = i));
    }
    return CupertinoPageScaffold(child: screen);
  }

  static void _noop() {}
}

class _Tabbed extends StatefulWidget {
  const _Tabbed({required this.initial, required this.onTab});
  final int initial;
  final ValueChanged<int> onTab;

  @override
  State<_Tabbed> createState() => _TabbedState();
}

class _TabbedState extends State<_Tabbed> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  CupertinoButton(
                    onPressed: () {
                      store.tab = i;
                      widget.onTab(i);
                    },
                    child: Text(RootShell.tabs[i].label),
                  ),
              ],
            ),
            Expanded(
              child: switch (widget.initial) {
                0 => const HomeScreen(),
                1 => const ChatsScreen(),
                2 => const AppointmentsScreen(),
                3 => const ShopsScreen(),
                _ => const ProfileScreen(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
