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

  Widget _field({required String label, required Widget badge, required IconData icon, required Color iconBg, required Color iconFg, required Widget input, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Rad.lg),
        boxShadow: const [
          BoxShadow(color: Color(0x0D2D2B38), blurRadius: 28, offset: Offset(0, 10), spreadRadius: -6),
          BoxShadow(color: Color(0x085B3CDD), blurRadius: 8, offset: Offset(0, 2), spreadRadius: -2),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label.toUpperCase(), style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(0.8)),
          const Spacer(),
          badge,
        ]),
        const SizedBox(height: 6),
        Row(children: [
          IconCircle(icon, size: 40, iconSize: 20, bg: iconBg, fg: iconFg, fill: 1),
          const SizedBox(width: Sp.sm),
          Expanded(child: input),
          if (trailing != null) trailing,
        ]),
      ]),
    );
  }

  InputDecoration get _bare => InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintStyle: T.bodyLg.c(AppColors.outlineVariant).medium,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      );

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: BrandBackHeader(onBack: () => context.canPop() ? context.pop() : context.go('/onboarding')),
      spacing: Sp.sm,
      children: [
        // Mascot + heading
        SizedBox(
          height: 200,
          child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
            Positioned(top: -24, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.5), size: 176)),
            Positioned(top: 16, right: 24, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 144)),
            Column(children: [
              const SizedBox(height: 6),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x2E984062), blurRadius: 24, offset: Offset(0, 12))]),
                    child: const AssetImg('heart_embrace', radius: 28),
                  )),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: AppColors.tertiaryFixed, shape: BoxShape.circle, boxShadow: Shadows.tiny),
                      child: Icon(Symbols.auto_awesome, size: 14, color: AppColors.onTertiaryFixedVariant, fill: 1),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              Text(_login ? 'Welcome Back' : 'Create Your Account', style: T.headlineXlMobile),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.schedule, size: 16, color: AppColors.tertiary),
                const SizedBox(width: 6),
                Text(_login ? 'Pick up right where you left off' : 'Takes less than a minute', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ]),
            ]),
          ]),
        ),
        if (!_login)
          _field(
            label: 'Full Name',
            badge: Text('Preferred name is fine', style: T.labelSm.c(AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
            icon: Symbols.person_pin,
            iconBg: AppColors.primaryFixed.withValues(alpha: 0.6),
            iconFg: AppColors.primary,
            input: TextField(controller: _name, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], style: T.bodyLg.medium, decoration: _bare.copyWith(hintText: 'Nimal Perera')),
          ),
        _field(
          label: 'University Email',
          badge: TagPill('Student Verified', icon: Symbols.verified, fill: 1, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixedVariant),
          icon: Symbols.school,
          iconBg: AppColors.surfaceContainerHigh,
          iconFg: AppColors.tertiary,
          input: TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], style: T.bodyLg.medium, decoration: _bare.copyWith(hintText: 'fst*****@agri.pdn.ac.lk')),
        ),
        _field(
          label: 'Password',
          badge: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Symbols.lock_reset, size: 14, color: AppColors.tertiary),
            const SizedBox(width: 2),
            Text('Encrypted', style: T.labelSm.c(AppColors.tertiary)),
          ]),
          icon: Symbols.lock,
          iconBg: AppColors.secondaryFixed.withValues(alpha: 0.7),
          iconFg: AppColors.secondary,
          input: TextField(
            controller: _password,
            obscureText: _obscure,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            autofillHints: [_login ? AutofillHints.password : AutofillHints.newPassword],
            style: T.bodyLg.medium,
            decoration: _bare.copyWith(hintText: _login ? 'Your password' : 'Create a strong password'),
          ),
          trailing: CircleButton(_obscure ? Symbols.visibility : Symbols.visibility_off, size: 36, iconSize: 19, bg: AppColors.surfaceContainerLow, onTap: () => setState(() => _obscure = !_obscure)),
        ),
        if (!_login)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.check_circle, size: 16, fill: 1, color: _passwordOk ? AppColors.tertiary : AppColors.outlineVariant),
              const SizedBox(width: 6),
              Expanded(child: Text('At least 8 characters with a healthy mix of letters and numbers.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.3))),
            ]),
          )
        else
          Align(alignment: Alignment.centerRight, child: TextLinkButton('Forgot password?', color: AppColors.primary, onTap: _forgot)),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(Sp.sm),
            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(Rad.base)),
            child: Row(children: [
              Icon(Symbols.error, size: 18, color: AppColors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: T.bodySm.c(AppColors.onErrorContainer))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: PrimaryButton(_login ? 'Log In' : 'Create Account', icon: Symbols.arrow_forward, color: AppColors.tertiary, loading: _busy, onTap: _submit),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.md),
          child: Stack(alignment: Alignment.center, children: [
            Container(height: 1, color: AppColors.surfaceContainerHighest),
            Pill(
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shadow: Shadows.tiny,
              child: Text('OR CONTINUE WITH', style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(1)),
            ),
          ]),
        ),
        _socialButton(
          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle), alignment: Alignment.center, child: const _GoogleG()),
          'Google',
          _google,
        ),
        Container(
          margin: const EdgeInsets.only(top: Sp.sm),
          padding: const EdgeInsets.all(Sp.sm),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.lg)),
          child: Row(children: [
            const IconCircle(Symbols.health_and_safety, size: 32, iconSize: 17),
            const SizedBox(width: 12),
            Expanded(child: Text('Encrypted & private. Your wellness data remains private to you.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.3))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Sp.md),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_login ? 'New to VitalU?' : 'Already have an account?', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            GestureDetector(
              onTap: () => setState(() {
                _login = !_login;
                _error = null;
              }),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(_login ? 'Create account' : 'Log in',
                    style: T.labelLg.bold.c(AppColors.primary).copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.primary.withValues(alpha: 0.4))),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _socialButton(Widget leading, String label, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: Shadows.soft),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            leading,
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: T.labelMd, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

class _CheckEmail extends StatelessWidget {
  const _CheckEmail({required this.email});
  final String email;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconCircle(Symbols.mark_email_read, bg: AppColors.tertiaryFixed, fg: AppColors.tertiary, size: 52, iconSize: 26),
        const SizedBox(height: Sp.sm),
        Text('Check your inbox', style: T.headlineMd),
        const SizedBox(height: 6),
        Text('We sent a confirmation link to $email. Open it on this phone, then log in to continue setting up your space.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        PrimaryButton('Got it', color: AppColors.tertiary, onTap: () => Navigator.pop(context)),
      ]);
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => SizedBox(width: 16, height: 16, child: CustomPaint(painter: _GPainter()));
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
