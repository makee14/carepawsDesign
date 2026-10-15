import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'profile/privacy_screen.dart';

/// Sign-in gate between the splash and the app.
///
/// The credentials are checked on the device against [AppStore.demoEmail] /
/// [AppStore.demoPassword]. A wrong email or password is rejected with an
/// inline message and the form stays put — there is no way past this screen
/// without the right pair.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  /// Called once the credentials are accepted.
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _hidden = true;
  bool _registerMode = false;

  /// Whether the user ticked the Terms/Privacy consent box. Required before
  /// an account can be created.
  bool _consent = false;

  /// Link recognizers for the consent row; disposed with the state.
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalKind.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalKind.privacy);

  /// Raw message from the last failed submit. Rendered as an inline
  /// field-level error (red border + message under the field) instead of a
  /// banner card; cleared the moment the user edits any field.
  String? _formError;

  /// Which register-mode field [_formError] belongs to. Null in sign-in mode,
  /// where the neutral message implicates the email + password pair.
  _LoginField? _errorField;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = AppScope.read(context);
    HapticFeedback.lightImpact();
    if (_registerMode) {
      final ok = await store.register(
        _name.text,
        _email.text,
        _password.text,
        agreedToTermsAt: DateTime.now(),
      );
      if (!mounted) return;
      if (ok) {
        // Registration does not sign in. Drop back to the sign-in form with
        // the new email filled in, so the account is entered deliberately.
        successHaptic();
        setState(() {
          _registerMode = false;
          _consent = false;
          _password.clear();
          _formError = null;
          _errorField = null;
        });
        showToast(context, 'Account created — sign in with your new password.');
      } else {
        errorHaptic();
        setState(() {
          _formError = store.signInError;
          _errorField = store.signInError == null
              ? null
              : _fieldForRegisterError(store.signInError!);
        });
      }
      return;
    }
    final ok = await store.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (ok) {
      successHaptic();
      widget.onSignedIn();
    } else {
      errorHaptic();
      setState(() {
        _formError = store.signInError;
        _errorField = null; // the neutral message implicates the pair
      });
    }
  }

  /// Maps an [AuthStore.register] failure onto the field it belongs to. The
  /// messages are matched by content — they are AuthStore's own copy, whose
  /// API (in services/) this screen cannot change.
  _LoginField _fieldForRegisterError(String message) {
    final m = message.toLowerCase();
    if (m.contains('name')) return _LoginField.name;
    if (m.contains('email')) return _LoginField.email;
    return _LoginField.password;
  }

  void _clearError() {
    if (_formError == null) return;
    setState(() {
      _formError = null;
      _errorField = null;
    });
  }

  void _switchMode(bool register) {
    if (_registerMode == register) return;
    setState(() {
      _registerMode = register;
      _consent = false;
      _formError = null;
      _errorField = null;
      // Clear any stale error when switching modes.
      AppScope.read(context).signInError = null;
    });
  }

  /// Opens the terms/privacy copy in a bottom sheet. The form keeps its
  /// controllers, so the input is untouched when the sheet dismisses.
  void _openLegal(LegalKind kind) {
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kind == LegalKind.terms
                        ? 'Terms of service'
                        : 'Privacy policy',
                    style: Type.title2(context.p),
                    maxLines: 2,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => dismissSheet(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LegalContent(kind: kind),
          ],
        ),
      ),
    );
  }

  /// Why the Create account button is disabled right now — shown live under
  /// the button in register mode so the blocker is discoverable.
  String _disabledHint() {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      return 'Enter your name, email and password to continue.';
    }
    return 'Tick the box to agree to the Terms of Service and Privacy Policy.';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    final busy = store.signingIn;
    final canSubmit =
        !busy &&
        _email.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        (!_registerMode || (_name.text.trim().isNotEmpty && _consent));

    // Split the last failure onto its field: in sign-in mode the neutral
    // message implicates the pair (red border on both, text under password).
    String? nameError, emailError, passwordError;
    var emailInvalid = false, passwordInvalid = false;
    if (_formError != null) {
      if (_registerMode) {
        switch (_errorField) {
          case _LoginField.name:
            nameError = _formError;
          case _LoginField.email:
            emailError = _formError;
          case _LoginField.password:
          case null:
            passwordError = _formError;
        }
      } else {
        emailInvalid = true;
        passwordInvalid = true;
        passwordError = _formError;
      }
    }

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: _registerMode ? 'Create account' : 'Sign in',
        showBack: false,
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const FadeIn(child: Center(child: LogoMark(size: 96))),
            const SizedBox(height: T.s20),
            FadeIn(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _registerMode ? 'Join CarePaws' : 'Welcome back',
                    style: Type.title1(p),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _registerMode
                        ? 'Create an account to manage your pets, visits and messages.'
                        : 'Sign in to reach your pets, visits and messages.',
                    style: Type.body(p).copyWith(color: p.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.s24),
            FadeIn(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_registerMode) ...[
                    _Field(
                      label: 'Name',
                      controller: _name,
                      hint: 'Your first name',
                      icon: Ic.person,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      enabled: !busy,
                      errorText: nameError,
                      onChanged: (_) {
                        _clearError();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Field(
                    label: 'Email',
                    controller: _email,
                    hint: 'you@example.com',
                    icon: Ic.person,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !busy,
                    errorText: emailError,
                    invalid: emailInvalid,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    onChanged: (_) {
                      _clearError();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Password',
                    controller: _password,
                    hint: _registerMode
                        ? 'At least 8 characters'
                        : '••••••••••',
                    icon: Ic.lock,
                    obscure: _hidden,
                    enabled: !busy,
                    focusNode: _passwordFocus,
                    textInputAction: TextInputAction.go,
                    errorText: passwordError,
                    invalid: passwordInvalid,
                    onSubmitted: (_) {
                      if (canSubmit) _submit();
                    },
                    onChanged: (_) {
                      _clearError();
                      setState(() {});
                    },
                    suffix: IconTap(
                      path: Ic.eye,
                      label: _hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                  if (_registerMode) _PasswordRule(password: _password.text),
                  if (_registerMode) ...[
                    const SizedBox(height: T.s16),
                    _ConsentRow(
                      checked: _consent,
                      onChanged: (v) => setState(() => _consent = v),
                      termsTap: _termsTap,
                      privacyTap: _privacyTap,
                    ),
                  ],
                  const SizedBox(height: T.s20),
                  PrimaryButton(
                    label: _registerMode ? 'Create account' : 'Sign in',
                    icon: Ic.check,
                    busy: busy,
                    onPressed: canSubmit ? _submit : null,
                  ),
                  // Live hint naming the blocker while Create account is
                  // disabled — a disabled button can't explain itself.
                  if (_registerMode && !busy && !canSubmit) ...[
                    const SizedBox(height: 10),
                    Text(
                      _disabledHint(),
                      style: Type.caption(p).copyWith(color: p.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: T.s16),
            FadeIn(
              index: 3,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: busy ? null : () => _switchMode(!_registerMode),
                // The question stays quiet; the action reads as the tappable
                // option — bold, accent-coloured, underlined.
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _registerMode
                            ? 'Already have an account? '
                            : "Don't have an account? ",
                        style: Type.footnote(p)
                            .copyWith(color: p.textSecondary),
                      ),
                      TextSpan(
                        text: _registerMode ? 'Sign in' : 'Create one',
                        style: Type.footnote(p).copyWith(
                          color: p.accentText,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.suffix,
    this.enabled = true,
    this.errorText,
    this.invalid = false,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final Widget? suffix;
  final bool enabled;

  /// Concise message rendered under the field, with a red border.
  final String? errorText;

  /// Red border without a message (the message lives under a sibling field).
  final bool invalid;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final hasError = invalid || errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Type.footnoteEmph(p)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          placeholder: hint,
          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
          style: Type.body(p),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          cursorColor: p.primaryFill,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Ic.svg(icon, color: p.textSecondary, size: 18),
          ),
          suffix: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix,
                ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(
              color: hasError ? p.destructive : p.divider,
              width: hasError ? 1.5 : 1,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: Type.footnote(p).copyWith(color: p.destructive),
          ),
        ],
      ],
    );
  }
}

/// Which register-mode field a failure message belongs to.
enum _LoginField { name, email, password }

/// Live password-rule checklist under the create-account password field:
/// 8+ characters, a letter, a number. Each rule flips to a check the moment
/// it is satisfied, so the requirement is visible before submit.
class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final rules = [
      ('8+ characters', password.length >= 8),
      ('a letter (a–z)', RegExp(r'[A-Za-z]').hasMatch(password)),
      ('a number (0–9)', RegExp(r'[0-9]').hasMatch(password)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final (label, ok) in rules)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(
                  ok ? Ic.checkCircle : Ic.info,
                  color: ok ? p.success : p.textSecondary,
                  size: 14,
                  stroke: 2.2,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Type.caption(p).copyWith(
                    color: ok ? p.success : p.textSecondary,
                    fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Terms/Privacy consent row on the create-account form: a tappable
/// checkbox (44pt target) plus inline links that open the legal copy in a
/// sheet. The text wraps freely, so AX5 sizes never clip the row or the links.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.checked,
    required this.onChanged,
    required this.termsTap,
    required this.privacyTap,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final GestureRecognizer termsTap;
  final GestureRecognizer privacyTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final link = Type.footnote(p).copyWith(
      color: p.accentText,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          key: const Key('consent-checkbox'),
          label: 'Agree to the Terms of Service and Privacy Policy',
          button: true,
          checked: checked,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!checked),
            child: Padding(
              // 22pt glyph + 22pt padding = the 44pt HIG target.
              padding: const EdgeInsets.all(11),
              child: checked
                  ? Ic.svg(
                      Ic.checkCircle,
                      color: p.primaryFill,
                      size: 22,
                      stroke: 2.2,
                    )
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.textSecondary, width: 1.8),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 11, bottom: 11),
            child: Text.rich(
              TextSpan(
                style: Type.footnote(p).copyWith(color: p.textSecondary),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: link,
                    recognizer: termsTap,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: link,
                    recognizer: privacyTap,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Subtle transient confirmation — a small dark pill above the home indicator
/// that dismisses itself. Used for success confirmations where a banner card
/// would be too loud (account created, profile saved).
void showToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
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
