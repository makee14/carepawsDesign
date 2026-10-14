import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

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

  /// Shown once after a successful registration, on the sign-in form.
  String? _registeredNote;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = AppScope.read(context);
    HapticFeedback.lightImpact();
    if (_registerMode) {
      final ok = await store.register(_name.text, _email.text, _password.text);
      if (!mounted) return;
      if (ok) {
        // Registration does not sign in. Drop back to the sign-in form with
        // the new email filled in, so the account is entered deliberately.
        successHaptic();
        setState(() {
          _registerMode = false;
          _password.clear();
          _registeredNote =
              'Account created for ${_email.text.trim()} — sign in with your new password.';
        });
      } else {
        errorHaptic();
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
    }
  }

  void _switchMode(bool register) {
    if (_registerMode == register) return;
    setState(() {
      _registerMode = register;
      _registeredNote = null;
      // Clear any stale error when switching modes.
      AppScope.read(context).signInError = null;
    });
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
        (!_registerMode || _name.text.trim().isNotEmpty);

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
                      onChanged: (_) => setState(() {}),
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
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    onChanged: (_) => setState(() {}),
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
                    onSubmitted: (_) {
                      if (canSubmit) _submit();
                    },
                    onChanged: (_) => setState(() {}),
                    suffix: IconTap(
                      path: Ic.eye,
                      label: _hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                  if (_registerMode) _PasswordRule(password: _password.text),
                  if (_registeredNote != null && !_registerMode) ...[
                    const SizedBox(height: 12),
                    _InfoNote(text: _registeredNote!),
                  ],
                  if (store.signInError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorNote(text: store.signInError!),
                  ],
                  const SizedBox(height: T.s20),
                  PrimaryButton(
                    label: _registerMode ? 'Create account' : 'Sign in',
                    icon: Ic.check,
                    busy: busy,
                    onPressed: canSubmit ? _submit : null,
                  ),
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
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
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
            border: Border.all(color: p.divider),
          ),
        ),
      ],
    );
  }
}

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

/// Neutral confirmation note — green-tinted, never alarming.
class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.success.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(Ic.checkCircle, color: p.success, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Type.footnote(p).copyWith(color: p.success),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.destructive.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.destructive.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(Ic.alert, color: p.destructive, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Type.footnote(p).copyWith(color: p.destructive),
            ),
          ),
        ],
      ),
    );
  }
}
