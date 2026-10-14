import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/sfx.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _modes = <(ThemeMode, String, String, IconData)>[
    (ThemeMode.light, 'Light', 'Always use the light look', Symbols.light_mode_rounded),
    (ThemeMode.dark, 'Dark', 'Always use the dark look', Symbols.dark_mode_rounded),
    (ThemeMode.system, 'System Default', 'Follow your phone\'s setting', Symbols.brightness_auto_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final current = AppState.instance.themeMode;
        return VPage(
          header: TitleHeader('Settings', onLeading: () => goBack(context, '/profile')),
          children: [
            ListGroup(header: 'Mode', dividerIndent: 60, children: [
              for (final m in _modes)
                ListRow(
                  icon: m.$4,
                  color: AppColors.primary,
                  title: m.$2,
                  subtitle: m.$3,
                  chevron: false,
                  trailing: Icon(current == m.$1 ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                      color: current == m.$1 ? AppColors.primary : AppColors.outline),
                  onTap: () => AppState.instance.setThemeMode(m.$1),
                ),
            ]),
            ValueListenableBuilder<bool>(
              valueListenable: Sfx.enabled,
              builder: (_, on, _) => ListGroup(header: 'Sounds', children: [
                ListRow(
                  icon: Symbols.volume_up_rounded,
                  color: AppColors.mind,
                  title: 'Sound effects',
                  subtitle: 'Water pouring and badge celebrations',
                  trailing: Switch(value: on, onChanged: Sfx.setEnabled),
                ),
              ]),
            ),
            Text('Notification settings are in the bell menu on the Home screen.', style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        );
      },
    );
  }
}
