import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../services/photo_store.dart';
import '../../state/app_store.dart';
import '../../state/profile_store.dart';
import '../../widgets/common.dart';
import '../onboarding_screen.dart';
import '../photo_crop_screen.dart';
import 'privacy_screen.dart';
import '../../services/ai_service.dart'
    show AiFailure, AiProvider, AiProviderInfo, AiStatus;

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
                    subtitle: store.ownerName,
                    leadingPath: Ic.person,
                    onTap: () =>
                        Navigator.of(context)
                            .push(appRoute(const EditProfileScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Language',
                    subtitle: store.language,
                    leadingPath: Ic.globe,
                    onTap: () =>
                        Navigator.of(context)
                            .push(appRoute(const LanguageScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Appearance',
                    subtitle: store.themeMode.label,
                    leadingPath: store.darkMode ? Ic.moon : Ic.sun,
                    onTap: () =>
                        Navigator.of(context)
                            .push(appRoute(const AppearanceScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Reduce motion',
                    subtitle: store.reduceMotionOverride
                        ? 'Animations are off'
                        : 'Following the system setting',
                    leadingPath: Ic.refresh,
                    onTap: () =>
                        store.setReduceMotion(!store.reduceMotionOverride),
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
            Text('CarePaws AI', style: Type.headline(p)),
            const SizedBox(height: 10),
            SoftCard(
              padding: EdgeInsets.zero,
              child: RowTile(
                title: 'AI providers',
                subtitle: store.ai.isLive
                    ? 'Live · ${store.ai.modelLabel}'
                    : 'Unavailable — add a key',
                leadingPath: Ic.sparkle,
                onTap: () =>
                    Navigator.of(context)
                        .push(appRoute(const AiSettingsScreen())),
              ),
            ),
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
                    onTap: () =>
                        Navigator.of(context)
                            .push(appRoute(const PrivacyScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Export my data',
                    subtitle: 'Pets, visits and orders as JSON',
                    leadingPath: Ic.download,
                    onTap: () =>
                        Navigator.of(context)
                            .push(appRoute(const ExportScreen())),
                  ),
                  Divider(height: 1, color: p.divider, indent: 58),
                  RowTile(
                    title: 'Sign out',
                    subtitle: store.signedIn
                        ? 'Signed in as ${store.accountEmail ?? AppStore.demoEmail}'
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

/// A standalone destination for the AI provider list.
///
/// Reachable straight from the Profile tab so a key never has to be hunted
/// for inside the full Settings screen.
class AiSettingsScreen extends StatelessWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'CarePaws AI'),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const _AiStatusCard(),
            const SizedBox(height: T.s20),
            Text('Providers', style: Type.headline(p)),
            const SizedBox(height: 10),
            for (final provider in store.ai.providers) ...[
              _ProviderCard(provider: provider),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: T.s8),
            Text(
              'Requests try each ready provider in order — Gemini, then OpenAI, '
              'then OpenRouter — and move to the next one automatically if a '
              'request fails.',
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Testing only — keys are stored in plaintext on this device. '
              'Remove them before shipping a build.',
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overall status: which provider answers first right now, and the routing
/// order behind it.
class _AiStatusCard extends StatelessWidget {
  const _AiStatusCard();

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final ai = AppScope.of(context).ai;
    return SoftCard(
      child: Row(
        children: [
          Ic.svg(
            ai.isLive ? Ic.checkCircle : Ic.sparkle,
            color: ai.isLive ? p.success : p.accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ai.isLive ? 'Live model connected' : 'AI unavailable',
                  style: Type.headline(p),
                ),
                const SizedBox(height: 2),
                Text(
                  ai.isLive
                      ? '${ai.modelLabel} answers first. If a request fails, it moves to the next ready provider automatically.'
                      : '${(ai.failure ?? AiFailure.noKey).label}. ${(ai.failure ?? AiFailure.noKey).hint}',
                  style: Type.footnote(p).copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusChip(
            label: ai.status == AiStatus.checking
                ? 'Checking'
                : ai.isLive
                ? 'Live'
                : 'Unavailable',
            compact: true,
            fg: ai.isLive ? p.success : p.warning,
            bg: ai.isLive
                ? (p.isDark
                      ? p.success.withValues(alpha: 0.12)
                      : const Color(0xFFDDF2E3))
                : T.amber.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}

/// One provider row: name, live model or key state, on/off switch. Tapping
/// expands the key field — paste, show/hide, save, remove, test — so each
/// provider is managed independently.
class _ProviderCard extends StatefulWidget {
  const _ProviderCard({required this.provider});
  final AiProvider provider;

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  bool _expanded = false;

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
    final ok = await store.setAiKeyFor(widget.provider, _controller.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _controller.clear();
      setState(() => _hidden = true);
    }
    if (!context.mounted) return;
    final status = store.ai.statusFor(widget.provider);
    // ok means the provider answered. A saved-but-silent key is reported
    // honestly instead of as "ready".
    final keySaved = status.keyConfigured;
    await showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(
              ok ? Ic.checkCircle : Ic.alert,
              color: ok ? context.p.success : context.p.destructive,
              size: 26,
            ),
            const SizedBox(height: 10),
            Text(
              ok
                  ? '${widget.provider.label} is ready'
                  : keySaved
                  ? 'Key saved'
                  : 'That key was not accepted',
              style: Type.title2(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ok
                  ? 'Answering on ${status.modelLabel}.'
                  : keySaved
                  ? 'The provider did not answer just now — it will be retried automatically.'
                  : '${(status.failure ?? AiFailure.serviceError).label}. ${(status.failure ?? AiFailure.serviceError).hint}',
              style: Type.footnote(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
            PrimaryButton(
              label: 'Done',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await AppScope.read(context).clearAiKeyFor(widget.provider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _controller.clear();
    });
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    await AppScope.read(context).recheckAi();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    final status = store.ai.statusFor(widget.provider);

    final String subtitle;
    final String chipLabel;
    final Color chipFg;
    final Color chipBg;
    if (!status.enabled) {
      subtitle = 'Turned off';
      chipLabel = 'Off';
      chipFg = p.textSecondary;
      chipBg = p.fieldBg;
    } else if (status.isLive) {
      subtitle = status.modelLabel ?? 'Connected';
      chipLabel = 'Live';
      chipFg = p.success;
      chipBg = const Color(0xFFDDF2E3);
    } else if (status.keyConfigured) {
      subtitle = status.failure?.label ?? 'Key saved';
      chipLabel = 'Key saved';
      chipFg = p.warning;
      chipBg = T.amber.withValues(alpha: 0.28);
    } else {
      subtitle = 'No key yet';
      chipLabel = 'No key';
      chipFg = p.textSecondary;
      chipBg = p.fieldBg;
    }

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressScale(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    widget.provider.label.substring(0, 1),
                    style: Type.headline(p).copyWith(color: p.accentText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.provider.label, style: Type.headline(p)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Type.footnote(p)
                            .copyWith(color: p.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: chipLabel,
                  compact: true,
                  fg: chipFg,
                  bg: chipBg,
                ),
                const SizedBox(width: 8),
                CupertinoSwitch(
                  value: status.enabled,
                  activeTrackColor: p.accent,
                  onChanged: _busy
                      ? null
                      : (v) => store.setAiProviderEnabled(widget.provider, v),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: T.s16),
            CupertinoTextField(
              controller: _controller,
              obscureText: _hidden,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: widget.provider.keyHint,
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
                    label: status.keyFromDevice ? 'Replace key' : 'Save key',
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
            if (status.keyFromDevice) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Remove key',
                      icon: Ic.trash,
                      onPressed: _busy ? null : _clear,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Test connection',
                      icon: Ic.refresh,
                      onPressed: _busy ? null : _test,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
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
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _picking = false;
  bool _saving = false;
  Map<ProfileField, String>? _errors;

  @override
  void initState() {
    super.initState();
    final store = AppScope.read(context);
    _name = TextEditingController(text: store.ownerName);
    _phone = TextEditingController(text: store.ownerPhone);
    _email = TextEditingController(text: store.ownerEmail);
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final bytes = await PhotoStore.pick(ImageSource.gallery);
      if (bytes == null || !mounted) return;
      // Crop/edit step before the photo becomes the owner portrait.
      final cropped = await Navigator.of(
        context,
      ).push<Uint8List?>(appRouteT<Uint8List?>(PhotoCropScreen(bytes: bytes)));
      if (cropped == null || !mounted) return;
      await AppScope.read(context).setOwnerPhoto(cropped);
      if (mounted) successHaptic();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// The old build never wrote anything here — it showed a fake "Profile
  /// saved." notice. This validates, persists per account, and refreshes the
  /// store, so the Profile tab and every greeting pick up the new values.
  Future<void> _save() async {
    if (_saving) return;
    final store = AppScope.read(context);
    setState(() {
      _saving = true;
      _errors = null;
    });
    final errors = await store.saveOwnerProfile(
      name: _name.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = errors;
    });
    if (errors == null) {
      successHaptic();
      // The toast lives on the ROOT overlay, not this tab's: it is app-level
      // feedback and must outlive the pop below. (An entry inserted into the
      // tab's own overlay never became visible once the route popped.)
      showToastOnOverlay(
        Overlay.of(context, rootOverlay: true),
        'Profile saved.',
      );
      Navigator.of(context).pop();
    } else {
      errorHaptic();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  /// True when name/phone differ from the saved profile. The email field is
  /// disabled and photo picks save immediately, so neither can be dirty.
  bool _dirty(AppStore store) =>
      _name.text != store.ownerName || _phone.text != store.ownerPhone;

  /// Nav-bar back / system back with unsaved edits: leave only on confirm.
  /// Saving pops directly (a direct pop bypasses PopScope), so this is only
  /// the abandon path.
  Future<void> _exit() async {
    final store = AppScope.read(context);
    if (await confirmDiscardIfDirty(context, isDirty: _dirty(store))) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    // Android system back honours the same dirty guard as the nav-bar back.
    return PopScope(
      canPop: !_dirty(store),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exit();
      },
      child: CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: DetailNavBar(
          title: 'Edit profile',
          onBack: () => _exit(),
        ),
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
                                initials: initialsOf(store.ownerName),
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
                    _Field(
                      label: 'Full name',
                      controller: _name,
                      icon: Ic.person,
                      keyboardType: TextInputType.name,
                      errorText: _errors?[ProfileField.name],
                      // Rebuild on keystroke so the PopScope dirty guard
                      // re-reads the controllers.
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: T.s16),
                    _Field(
                      label: 'Phone',
                      controller: _phone,
                      hint: '0917 000 0000',
                      icon: Ic.phone,
                      keyboardType: TextInputType.phone,
                      errorText: _errors?[ProfileField.phone],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: T.s16),
                    _Field(
                      label: 'Email',
                      controller: _email,
                      icon: Ic.person,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                      caption: 'Your sign-in email. To change it, contact the clinic.',
                    ),
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
                  busy: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle transient confirmation — a small dark pill above the home indicator
/// that dismisses itself. Duplicated from the sign-in screen: both flows need
/// it, and the shared widget kit is outside this workstream's ownership.
void showToast(BuildContext context, String message) {
  showToastOnOverlay(Overlay.of(context), message);
}

/// [showToast] against an explicitly captured overlay, for callers that pop
/// a route right after: the entry must land on an overlay that outlives the
/// pop.
void showToastOnOverlay(OverlayState overlay, String message) {
  late final OverlayEntry entry;
  var dismissed = false;
  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    entry.remove();
  }

  entry = OverlayEntry(builder: (_) => _Toast(message: message));
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2400), dismiss);
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(context).bottom + 28,
      // Never blocks touches — it is purely informational and dismisses
      // itself. No animation: with nothing moving there is no reduced-motion
      // variant to honor.
      child: IgnorePointer(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: message,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: T.espresso.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message,
                style: Type.footnote(p).copyWith(color: T.cream),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.caption,
    this.keyboardType,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String icon;
  final String? hint;
  final String? caption;
  final TextInputType? keyboardType;
  final bool enabled;

  /// Concise message rendered under the field, with a red border.
  final String? errorText;

  /// Notifies the parent on every keystroke (e.g. so dirty guards re-read
  /// the controller on the next build).
  final ValueChanged<String>? onChanged;

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
          enabled: enabled,
          keyboardType: keyboardType,
          onChanged: onChanged,
          autocorrect: false,
          enableSuggestions: false,
          style: Type.body(p),
          placeholder: hint,
          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
          padding: const EdgeInsets.all(14),
          cursorColor: p.primaryFill,
          decoration: BoxDecoration(
            color: enabled ? p.surface : p.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(
              color: errorText != null ? p.destructive : p.divider,
              width: errorText != null ? 1.5 : 1,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: Type.footnote(p).copyWith(color: p.destructive),
          ),
        ] else if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption!, style: Type.caption(p)),
        ],
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
              'CarePaws is available in English, Tagalog and Bisaya. Clinic records and receipts always stay '
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
                color: selected ? p.accent.withValues(alpha: 0.14) : p.fieldBg,
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
      'No. CarePaws AI is guidance. A veterinarian has to examine your pet to confirm anything.',
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
                      OnboardingScreen(onDone: () => dismissSheet(context)),
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
                      Text(
                        e.$2,
                        style: Type.body(p).copyWith(color: p.textSecondary),
                      ),
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
            PrimaryButton(
              label: 'Got it',
              onPressed: () => dismissSheet(context),
            ),
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
                Text(
                  faqs[i].$2,
                  style: Type.body(p).copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
