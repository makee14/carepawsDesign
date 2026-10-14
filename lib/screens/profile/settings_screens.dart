import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../services/photo_store.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../onboarding_screen.dart';
import 'privacy_screen.dart';
import '../../services/ai_service.dart' show AiFailure, AiStatus;

/// Consolidated settings surface reachable from the Profile nav bar.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Settings'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text('Account', style: Type.headline(p)),
            const SizedBox(height: 10),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  RowTile(
                    title: 'Edit profile',
                    subtitle: Seed.ownerName,
                    leadingPath: Ic.person,
                    onTap: () => Navigator.of(context).push(appRoute(const EditProfileScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Language',
                    subtitle: store.language,
                    leadingPath: Ic.globe,
                    onTap: () => Navigator.of(context).push(appRoute(const LanguageScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Appearance',
                    subtitle: store.themeMode.label,
                    leadingPath: store.darkMode ? Ic.moon : Ic.sun,
                    onTap: () => Navigator.of(context).push(appRoute(const AppearanceScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Reduce motion',
                    subtitle: store.reduceMotionOverride
                        ? 'Animations are off'
                        : 'Following the system setting',
                    leadingPath: Ic.refresh,
                    onTap: () => store.setReduceMotion(!store.reduceMotionOverride),
                    trailing: CupertinoSwitch(
                      value: store.reduceMotionOverride,
                      activeTrackColor: p.accent,
                      onChanged: (v) => store.setReduceMotion(v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.s20),
            Text('PetCare AI', style: Type.headline(p)),
            const SizedBox(height: 10),
            const AiSettingsCard(),
            const SizedBox(height: T.s20),
            Text('Data', style: Type.headline(p)),
            const SizedBox(height: 10),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  RowTile(
                    title: 'Privacy',
                    subtitle: 'Export data, delete account',
                    leadingPath: Ic.lock,
                    onTap: () => Navigator.of(context).push(appRoute(const PrivacyScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Export my data',
                    subtitle: 'Pets, visits and orders as JSON',
                    leadingPath: Ic.download,
                    onTap: () => Navigator.of(context).push(appRoute(const ExportScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Sign out',
                    subtitle: store.signedIn
                        ? 'Signed in as ${AppStore.demoEmail}'
                        : 'Not signed in',
                    leadingPath: Ic.close,
                    onTap: () => _confirmSignOut(context, store),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A standalone destination for [AiSettingsCard].
///
/// Reachable straight from the Profile tab so the Gemini key never has to be
/// hunted for inside the full Settings screen.
class AiSettingsScreen extends StatelessWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'PetCare AI'),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const AiSettingsCard(),
            const SizedBox(height: T.s20),
            Text(
              'The key decides whether health checks and chat can run on a real model. '
              'Without one, PetCare AI stays unavailable — everything else about the app works the same.',
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors the AI service status and lets a tester paste a key straight onto
/// the device — no rebuild, no `--dart-define`. The value is kept in
/// SharedPreferences in plaintext, so this is a testing affordance only.
class AiSettingsCard extends StatefulWidget {
  const AiSettingsCard({super.key});

  @override
  State<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<AiSettingsCard> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    setState(() {
      _controller.text = text;
      _hidden = false;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final store = AppScope.read(context);
    final ok = await store.setAiKey(_controller.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _controller.clear();
      setState(() => _hidden = true);
    }
    if (!context.mounted) return;
    await showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(ok ? Ic.checkCircle : Ic.alert, color: ok ? context.p.success : context.p.destructive, size: 26),
            const SizedBox(height: 10),
            Text(
              ok ? 'Live AI is on' : 'That key was not accepted',
              style: Type.title2(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ok
                  ? 'Health checks and chat now run on ${store.ai.modelLabel}.'
                  : '${(store.ai.failure ?? AiFailure.noKey).label}, so PetCare AI stayed unavailable. '
                        '${(store.ai.failure ?? AiFailure.noKey).hint}',
              style: Type.footnote(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
            PrimaryButton(label: 'Done', onPressed: () => dismissSheet(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    final ai = store.ai;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Ic.svg(Ic.sparkle, color: p.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ai.isLive ? 'Live model connected' : 'AI unavailable',
                  style: Type.headline(p),
                ),
              ),
              StatusChip(
                label: ai.status == AiStatus.checking
                    ? 'Checking'
                    : ai.isLive
                    ? 'Live'
                    : 'Unavailable',
                compact: true,
                fg: ai.isLive ? p.success : p.warning,
                bg: ai.isLive ? const Color(0xFFDDF2E3) : T.amber.withValues(alpha: 0.28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ai.isLive
                ? 'Model ${ai.modelLabel} was selected automatically from the available free-tier models that accept text and images.'
                : '${(ai.failure ?? AiFailure.noKey).label}. ${(ai.failure ?? AiFailure.noKey).hint}',
            style: Type.body(p).copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: T.s16),
          CupertinoTextField(
            controller: _controller,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            placeholder: 'AIza…',
            placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
            style: Type.body(p),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            cursorColor: p.primaryFill,
            decoration: BoxDecoration(
              color: p.fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.divider),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: ai.keyFromDevice ? 'Replace key' : 'Save key',
                  icon: Ic.check,
                  busy: _busy,
                  onPressed: _busy ? null : _save,
                ),
              ),
              const SizedBox(width: 10),
              IconTap(
                path: Ic.eye,
                label: _hidden ? 'Show key' : 'Hide key',
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
              const SizedBox(width: 6),
              IconTap(
                path: Ic.close,
                label: 'Paste key',
                onPressed: _busy ? null : _paste,
              ),
            ],
          ),
          if (ai.keyFromDevice) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Remove key from this device',
              icon: Ic.trash,
              onPressed: _busy ? null : _clear,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Testing only — the key is stored in plaintext on this device. '
            'Remove it before shipping a build.',
            style: Type.footnote(p).copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await AppScope.read(context).clearAiKey();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _controller.clear();
    });
  }
}

/// Clears the session and returns to the splash, so the sign-in flow can be
/// demonstrated again without relaunching the app.
Future<void> _confirmSignOut(BuildContext context, AppStore store) async {
  final ok = await showPopup<bool>(
    context,
    centered: true,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Sign out?'),
      content: const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('You will be returned to the welcome screen.'),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  store.signOut();
  // Unwind to the splash, which is the first route in the stack.
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// Circular camera badge that sits on the avatar's corner.
class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent,
              shape: BoxShape.circle,
              border: Border.all(color: p.background, width: 2),
              boxShadow: [
                BoxShadow(
                  color: T.taupe.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Ic.svg(icon, color: p.onPrimaryFill, size: 16, stroke: 2.2),
          ),
        ),
      ),
    );
  }
}

class _PhotoTextAction extends StatelessWidget {
  const _PhotoTextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label,
                style: Type.footnoteEmph(p).copyWith(color: p.accentText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: Seed.ownerName);
  late final _contact = TextEditingController(text: Seed.ownerContact);
  bool _picking = false;

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final bytes = await PhotoStore.pick(ImageSource.gallery);
      if (bytes == null || !mounted) return;
      await AppScope.read(context).setOwnerPhoto(bytes);
      if (mounted) successHaptic();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(title: 'Edit profile'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            OwnerAvatar(
                              initials: 'MD',
                              size: 96,
                              photo: store.ownerPhoto,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: _PhotoBadge(
                                icon: Ic.camera,
                                label: _picking ? 'Opening…' : 'Change photo',
                                busy: _picking,
                                onTap: _picking ? null : () => _pickPhoto(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PhotoTextAction(
                              label: 'Choose from library',
                              onTap: _picking ? null : () => _pickPhoto(),
                            ),
                            if (store.hasOwnerPhoto) ...[
                              const SizedBox(width: 14),
                              _PhotoTextAction(
                                label: 'Remove',
                                onTap: _picking
                                    ? null
                                    : () {
                                        store.setOwnerPhoto(null);
                                        successHaptic();
                                      },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s24),
                  _Field(label: 'Full name', controller: _name, icon: Ic.person),
                  const SizedBox(height: T.s16),
                  _Field(label: 'Contact', controller: _contact, icon: Ic.phone),
                  const SizedBox(height: T.s16),
                  SoftCard(
                    child: Row(
                      children: [
                        Ic.svg(Ic.info, color: p.textSecondary, size: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your phone number is what the clinic uses for appointment confirmations and reminders.',
                            style: Type.footnote(p),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'Save changes',
                icon: Ic.check,
                onPressed: () {
                  dismissSheet(context);
                  ScaffoldlessNotice.show(context, 'Profile saved.');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScaffoldlessNotice {
  static void show(BuildContext context, String message) {
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(Ic.checkCircle, color: context.p.success, size: 40, stroke: 1.9),
            const SizedBox(height: 12),
            Text(message, style: Type.headline(context.p), textAlign: TextAlign.center),
            const SizedBox(height: T.s20),
            PrimaryButton(label: 'OK', onPressed: () => dismissSheet(context)),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.icon});
  final String label;
  final TextEditingController controller;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Ic.svg(icon, color: p.accent, size: 16),
            const SizedBox(width: 7),
            Text(label, style: Type.headline(p)),
          ],
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          style: Type.body(p),
          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
          padding: const EdgeInsets.all(14),
          cursorColor: p.primaryFill,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(color: p.divider),
          ),
        ),
      ],
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const options = [
    ('English', 'English', true),
    ('Tagalog', 'Tagalog', false),
    ('Bisaya', 'Bisaya', false),
  ];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Language'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.divider, indent: 16),
                    RowTile(
                      title: options[i].$1,
                      subtitle: options[i].$2,
                      showChevron: false,
                      onTap: () {
                        store.setLanguage(options[i].$1);
                        dismissSheet(context);
                      },
                      trailing: SelectDot(
                        selected: store.language == options[i].$1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: T.s16),
            Text(
              'PetCare is available in English, Tagalog and Bisaya. Clinic records and receipts always stay '
              'in English so the vet team can read them.',
              style: Type.footnote(context.p),
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final mode = store.themeMode;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Appearance'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // iOS-style tri-state: Automatic follows the device, Light/Dark
            // pin an explicit choice. The old two-card layout had no way to
            // return to Automatic, so the store default (system) was
            // unreachable from the UI.
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ThemeRow(
                    label: 'Automatic',
                    subtitle: 'Follows the device appearance',
                    icon: Ic.refresh,
                    selected: mode == ThemeMode.system,
                    onTap: () => store.setThemeMode(ThemeMode.system),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  _ThemeRow(
                    label: 'Light',
                    subtitle: 'Warm cream theme',
                    icon: Ic.sun,
                    selected: mode == ThemeMode.light,
                    onTap: () => store.setThemeMode(ThemeMode.light),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  _ThemeRow(
                    label: 'Dark',
                    subtitle: 'Warm espresso theme',
                    icon: Ic.moon,
                    selected: mode == ThemeMode.dark,
                    onTap: () => store.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.s16),
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ic.svg(Ic.info, color: p.textSecondary, size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Automatic is the default and follows the device. Dark uses the matching token set so every '
                      'contrast pair still passes WCAG AA.',
                      style: Type.footnote(p),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? p.accent.withValues(alpha: 0.14)
                    : p.fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Ic.svg(
                  icon,
                  color: selected ? p.accent : p.textSecondary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Type.headline(p)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Type.footnote(p)),
                ],
              ),
            ),
            SelectDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const entries = [
    (
      'How do I book a visit?',
      'Home → quick action “Book”, or Appointments → the + button. Pick the pet, run the health check '
          'if you want (it is optional), choose the service, then a date and time. You see the total '
          'before you confirm.',
    ),
    (
      'Why did my booking become a request?',
      'Visits for a sick pet go to the vet assistant as a request so a veterinarian can review the '
          'health check first. Routine visits confirm instantly.',
    ),
    (
      'How do I collect an order?',
      'Everything is pickup only. Pay at checkout, then show the pickup code at the clinic counter. '
          'We hold paid orders for 7 days.',
    ),
    (
      'A product says “prescription required”.',
      'Restricted medicines need an active digital prescription signed by the veterinarian. Book a '
          'consultation and the clinic can issue one — then checkout will accept the item.',
    ),
    (
      'How do reminders work?',
      'Profile → Notifications lets you toggle medications, vaccine dates, appointment alerts (24h and '
          '2h before) and grooming rebooks separately.',
    ),
    (
      'Is my health check a diagnosis?',
      'No. PetCare AI is guidance. A veterinarian has to examine your pet to confirm anything.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Help centre'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            SoftCard(
              padding: EdgeInsets.zero,
              child: RowTile(
                title: 'Take the tour again',
                subtitle: 'Replay the 5-page introduction',
                leadingPath: Ic.sparkle,
                onTap: () {
                  AppScope.read(context).replayOnboarding();
                  Navigator.of(context).push(
                    appRoute(
                      OnboardingScreen(
                        onDone: () => dismissSheet(context),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: T.s16),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(e.$1, style: Type.headline(p))),
                          IconTap(
                            path: Ic.chevronDown,
                            label: 'Expand ${e.$1}',
                            color: p.primaryFill,
                            onPressed: () => _toggle(context, e.$1, e.$2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(e.$2, style: Type.body(p).copyWith(color: p.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggle(BuildContext context, String q, String a) {
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(q, style: Type.title2(context.p), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(a, style: Type.body(context.p), textAlign: TextAlign.center),
            const SizedBox(height: T.s20),
            PrimaryButton(label: 'Got it', onPressed: () => dismissSheet(context)),
          ],
        ),
      ),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final faqs = [
      (
        'How long does a grooming visit take?',
        'Full grooming is about 2 hours, bath and brush about 1 hour, and nail trim with ears around '
            '20 minutes. Booking a slot reserves the whole block.',
      ),
      (
        'Do you deliver shop orders?',
        'No. Everything is collected at the clinic counter. Paid orders are held for 7 days, and unpaid '
            'orders are released after 24 hours.',
      ),
      (
        'Can I pay with GCash?',
        'Yes — GCash and credit or debit cards are both accepted at checkout. One screen, one Pay button, '
            'and you get a pickup code straight away.',
      ),
      (
        'What is the clinic response time in chat?',
        'The vet assistant replies during clinic hours, usually within about 10 minutes. Outside those '
            'hours you will see exactly when replies resume.',
      ),
      (
        'Is the clinic open on Sundays?',
        'No — the clinic is closed on Sundays. Hours are Mon–Sat 9:00 AM to 6:00 PM. After hours, the nearest 24-hour animal '
            'hospital is listed on the Home screen.',
      ),
      (
        'Can I cancel an appointment?',
        'Yes, from the appointment card or the detail screen. You can also rebook in the same number of taps, '
            'and past visits have a one-tap Rebook that skips triage.',
      ),
      ('What time is it right now?', clinicStatusLine(store.now)),
    ];

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'FAQs'),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: faqs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faqs[i].$1, style: Type.headline(p)),
                const SizedBox(height: 6),
                Text(faqs[i].$2, style: Type.body(p).copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}