import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Web (GitHub Pages) redirects back to the page the app is served from;
/// mobile uses the app's deep link.
final authRedirect = kIsWeb ? Uri.base.origin + Uri.base.path.replaceFirst(RegExp(r'[^/]*$'), '') : 'lk.vitalu.app://login-callback';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.login = false});
  final bool login;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _login = widget.login;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _passwordOk => _password.text.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(_password.text) && RegExp(r'\d').hasMatch(_password.text);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final pass = _password.text;
    setState(() => _error = null);
    if (!_login && _name.text.trim().isEmpty) return setState(() => _error = 'Please tell us what to call you.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return setState(() => _error = 'Please enter a valid email address.');
    if (!_login && !_passwordOk) return setState(() => _error = 'Use at least 8 characters with letters and numbers.');
    if (_login && pass.isEmpty) return setState(() => _error = 'Please enter your password.');

    setState(() => _busy = true);
    try {
      if (_login) {
        await db.auth.signInWithPassword(email: email, password: pass);
        final p = await AppState.instance.loadProfile();
        if (!mounted) return;
        context.go(p == null || p.onboardingCompleted ? '/home' : '/register/${(p.registrationStep + 1).clamp(1, 3)}');
      } else {
        final res = await db.auth.signUp(email: email, password: pass, data: {'full_name': _name.text.trim()}, emailRedirectTo: authRedirect);
        if (!mounted) return;
        if (res.session == null) {
          await showVSheet(context, builder: (ctx) => _CheckEmail(email: email));
          if (mounted) setState(() => _login = true);
        } else {
          await AppState.instance.loadProfile();
          if (mounted) context.go('/register/1');
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    try {
      await db.auth.signInWithOAuth(OAuthProvider.google, redirectTo: authRedirect);
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) return toast(context, 'Enter your email above first.');
    try {
      await db.auth.resetPasswordForEmail(email, redirectTo: authRedirect);
      if (mounted) toast(context, 'Password reset link sent to $email');
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Widget _labeled(String label, Widget field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant))),
        field,
      ]);

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: BrandBackHeader(onBack: () => context.canPop() ? context.pop() : context.go('/onboarding')),
      spacing: Sp.md,
      topPadding: Sp.sm,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppIconTile(size: 52),
          const SizedBox(height: Sp.md),
          Text(_login ? 'Welcome back' : 'Create your account', style: T.headlineXlMobile),
          const SizedBox(height: 4),
          Text(_login ? 'Log in to continue.' : 'Use your university email. It takes a minute.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        const SizedBox(height: Sp.xs),
        if (!_login)
          _labeled(
            'Name',
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              style: T.bodyLg,
              decoration: InputDecoration(hintText: 'Nimal Perera', prefixIcon: Icon(Symbols.person_rounded, size: 20, color: AppColors.onSurfaceVariant)),
            ),
          ),
        _labeled(
          'University email',
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: T.bodyLg,
            decoration: InputDecoration(hintText: 'fst*****@agri.pdn.ac.lk', prefixIcon: Icon(Symbols.mail_rounded, size: 20, color: AppColors.onSurfaceVariant)),
          ),
        ),
        _labeled(
          'Password',
          TextField(
            controller: _password,
            obscureText: _obscure,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            autofillHints: [_login ? AutofillHints.password : AutofillHints.newPassword],
            style: T.bodyLg,
            decoration: InputDecoration(
              hintText: _login ? 'Your password' : 'At least 8 characters',
              prefixIcon: Icon(Symbols.lock_rounded, size: 20, color: AppColors.onSurfaceVariant),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Symbols.visibility_rounded : Symbols.visibility_off_rounded, size: 20, color: AppColors.onSurfaceVariant),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
        if (!_login)
          Row(children: [
            Icon(_passwordOk ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded, size: 16, fill: 1, color: _passwordOk ? AppColors.tertiary : AppColors.outline),
            const SizedBox(width: 6),
            Expanded(child: Text('8+ characters with letters and numbers', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          ])
        else
          Align(alignment: Alignment.centerRight, child: TextLinkButton('Forgot password?', onTap: _forgot)),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(Rad.base)),
            child: Row(children: [
              Icon(Symbols.error_rounded, size: 18, color: AppColors.onErrorContainer, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: T.bodySm.c(AppColors.onErrorContainer))),
            ]),
          ),
        PrimaryButton(_login ? 'Log in' : 'Create account', loading: _busy, onTap: _submit),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          const Expanded(child: Divider()),
        ]),
        OutlinedButton(
          onPressed: _google,
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _GoogleG(),
            SizedBox(width: 12),
            Text('Continue with Google'),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_login ? 'New to VitalU?' : 'Already have an account?', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          TextLinkButton(_login ? 'Create account' : 'Log in', onTap: () => setState(() {
                _login = !_login;
                _error = null;
              })),
        ]),
        const PrivacyNote('Your health data stays private to your account.'),
      ],
    );
  }
}

class _CheckEmail extends StatelessWidget {
  const _CheckEmail({required this.email});
  final String email;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconCircle(Symbols.mark_email_read_rounded, fg: AppColors.primary, size: 52, iconSize: 26),
        const SizedBox(height: Sp.md),
        Text('Check your inbox', style: T.headlineMd),
        const SizedBox(height: 6),
        Text('We sent a confirmation link to $email. Open it on this phone, then log in to finish setting up.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.lg),
        PrimaryButton('OK', onTap: () => Navigator.pop(context)),
      ]);
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => SizedBox(width: 18, height: 18, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(1.5, 1.5, s.width - 3, s.height - 3);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const pi = 3.1415926;
    p.color = const Color(0xFFEA4335);
    canvas.drawArc(r, -pi * 0.95, pi * 0.62, false, p);
    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(r, pi * 0.72, pi * 0.36, false, p);
    p.color = const Color(0xFF34A853);
    canvas.drawArc(r, pi * 0.2, pi * 0.52, false, p);
    p.color = const Color(0xFF4285F4);
    canvas.drawArc(r, -pi * 0.05, pi * 0.25, false, p);
    canvas.drawLine(Offset(s.width / 2, s.height / 2), Offset(s.width - 1.5, s.height / 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
