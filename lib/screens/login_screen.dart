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
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = AppScope.read(context);
    HapticFeedback.lightImpact();
    final ok = await store.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (ok) {
      successHaptic();
      widget.onSignedIn();
    } else {
      errorHaptic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    final busy = store.signingIn;
    final canSubmit = !busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Sign in', showBack: false),
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
                  Text('Welcome back', style: Type.title1(p), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to reach your pets, visits and messages.',
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
                    hint: '••••••••••',
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
                  if (store.signInError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorNote(text: store.signInError!),
                  ],
                  const SizedBox(height: T.s20),
                  PrimaryButton(
                    label: 'Sign in',
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
              child: Text(
                'Use the account your clinic set up for you.',
                style: Type.footnote(p).copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
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
              : Padding(padding: const EdgeInsets.only(right: 8), child: suffix),
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
