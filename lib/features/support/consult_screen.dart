import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'professionals_screen.dart' show callNumber;

const _codesKey = 'anon_consult_codes';

/// Ask the university health centre a question without revealing who you
/// are. The question is stored with no link to the account; the student
/// keeps a ticket code (on this device) to read the reply.
class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key});
  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  static const _topics = <(String, IconData)>[
    ('Physical health', Symbols.stethoscope_rounded),
    ('Mental health', Symbols.psychology_rounded),
    ('Sexual and reproductive health', Symbols.female_rounded),
    ('Medicines', Symbols.medication_rounded),
    ('Food and weight', Symbols.restaurant_rounded),
    ('Something else', Symbols.help_rounded),
  ];
  static const _urgency = <(String, String, String)>[
    ('routine', 'Routine', 'A reply in a few days is fine'),
    ('soon', 'Soon', 'Within a day, please'),
    ('urgent', 'Urgent', 'I need guidance today'),
  ];

  String? _topic;
  String _level = 'routine';
  final _msg = TextEditingController();
  bool _sending = false;
  List<String> _codes = [];
  List<Rec> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _msg.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _codes = prefs.getStringList(_codesKey) ?? [];
      _mine = await Repo.anonConsultations(_codes);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool get _ready => _topic != null && _msg.text.trim().length >= 5;

  Future<void> _send() async {
    if (!_ready) return;
    setState(() => _sending = true);
    try {
      final code = await Repo.submitAnonConsultation(topic: _topic!, message: _msg.text.trim(), urgency: _level);
      final prefs = await SharedPreferences.getInstance();
      _codes = [code, ..._codes];
      await prefs.setStringList(_codesKey, _codes);
      _msg.clear();
      setState(() => _topic = null);
      await _load();
      if (mounted) await _sent(code);
    } catch (_) {
      if (mounted) toast(context, 'Could not send your question right now. Please try again, or call the health centre.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sent(String code) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Symbols.mark_email_read_rounded, color: AppColors.primary, size: 36, fill: 1),
          title: const Text('Question sent anonymously'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Your ticket code', style: T.labelMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 4),
            SelectableText(code, style: T.metric(28)),
            const SizedBox(height: 8),
            Text('The reply will appear on this screen. The code is saved on this phone only, so note it down if you might switch phones.',
                textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
              },
              child: const Text('Copy code'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Ask anonymously', onLeading: () => goBack(context, '/home')),
      onRefresh: _load,
      children: [
        _emergency(),
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.xl),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
              Color.alphaBlend(AppColors.primary.withValues(alpha: AppColors.isDark ? 0.26 : 0.14), AppColors.surfaceContainerLowest),
              Color.alphaBlend(AppColors.primary.withValues(alpha: AppColors.isDark ? 0.08 : 0.03), AppColors.surfaceContainerLowest),
            ]),
          ),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/icons3d/consult.jpg', width: 72, height: 72, fit: BoxFit.cover)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('University health centre', style: T.labelSm.c(AppColors.primary).w(FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Ask without sharing who you are', style: T.headlineSm),
                const SizedBox(height: 4),
                Text('Your question is sent with no name, email or registration number attached.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        const SectionHeader('What is it about?'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _topics) VChip(t.$1, icon: t.$2, selected: _topic == t.$1, selectedColor: AppColors.primary, onTap: () => setState(() => _topic = t.$1)),
        ]),
        const SectionHeader('How soon do you need guidance?'),
        ListGroup(dividerIndent: 16, children: [
          for (final u in _urgency)
            ListRow(
              title: u.$2,
              subtitle: u.$3,
              chevron: false,
              trailing: Icon(_level == u.$1 ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  color: _level == u.$1 ? (u.$1 == 'urgent' ? AppColors.error : AppColors.primary) : AppColors.outline),
              onTap: () => setState(() => _level = u.$1),
            ),
        ]),
        if (_level == 'urgent')
          VCard(
            color: AppColors.errorContainer,
            flat: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.warning_rounded, color: AppColors.onErrorContainer, fill: 1),
              const SizedBox(width: 10),
              Expanded(
                child: Text('If you are unwell right now, injured, or thinking of harming yourself, do not wait for a reply: call the University Health Centre on 081 239 2022 (open 24/7), 1990 for an ambulance or 1926, or go to the nearest hospital.',
                    style: T.bodyMd.c(AppColors.onErrorContainer)),
              ),
            ]),
          ),
        const SectionHeader('Your question'),
        VTextField(controller: _msg, hint: 'Describe what is going on. Please leave out names or details that could identify you.', maxLines: 6),
        PrimaryButton('Send anonymously', leadingIcon: Symbols.send_rounded, loading: _sending, onTap: _ready ? _send : null),
        if (!_loading && _mine.isNotEmpty) ...[
          const SectionHeader('Your questions', subtitle: 'Saved on this phone by ticket code'),
          for (final m in _mine) _ticket(m),
        ],
        const PrivacyNote('Health centre staff see only your question, topic and urgency. They cannot see your account.'),
      ],
    );
  }

  Widget _emergency() => Material(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(Rad.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => callNumber(context, '1990'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Icon(Symbols.emergency_rounded, color: AppColors.onErrorContainer, fill: 1, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Is this an emergency?', style: T.labelLg.w(FontWeight.w800).c(AppColors.onErrorContainer)),
                  Text('Call 1990 Suwa Seriya ambulance now. For a mental health crisis, call 1926.', style: T.bodySm.c(AppColors.onErrorContainer)),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(Rad.full)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.call_rounded, size: 16, color: AppColors.onError, fill: 1),
                  const SizedBox(width: 4),
                  Text('1990', style: T.labelMd.w(FontWeight.w800).c(AppColors.onError)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _ticket(Rec m) {
    final answered = m['reply'] != null && (m['reply'] as String).trim().isNotEmpty;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(m['code'], style: T.labelLg.w(FontWeight.w800).tnum),
          const SizedBox(width: 8),
          Expanded(child: Text('${m['topic']} · ${DateFormat('d MMM').format(DateTime.parse(m['created_at']).toLocal())}', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          TagPill(answered ? 'Answered' : 'Waiting', bg: AppColors.tint(answered ? AppColors.tertiary : AppColors.warning), fg: answered ? AppColors.tertiary : AppColors.warning),
        ]),
        const SizedBox(height: 8),
        Text(m['message'], style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 4, overflow: TextOverflow.ellipsis),
        if (answered) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.tint(AppColors.primary), borderRadius: BorderRadius.circular(Rad.base)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Symbols.support_agent_rounded, size: 16, color: AppColors.primary, fill: 1),
                const SizedBox(width: 6),
                Text('Health centre reply', style: T.labelMd.c(AppColors.primary)),
              ]),
              const SizedBox(height: 4),
              Text(m['reply'], style: T.bodyMd),
            ]),
          ),
        ],
        if (!answered) ...[
          const SizedBox(height: 6),
          TextLinkButton('Need help sooner? Get help now', leading: Symbols.call_rounded, onTap: () => context.push('/help')),
        ],
      ]),
    );
  }
}
