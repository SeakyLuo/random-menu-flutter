import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});
  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: const Text('外观')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final item in [
                ('system', '跟随系统', '随设备外观自动切换'),
                ('light', '浅色', '清爽明亮'),
                ('dark', '深色', '柔和深邃'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await performAction(
                                context,
                                () =>
                                    store.update((d) => d.themeMode = item.$1),
                              );
                              if (mounted) setState(() => _saving = false);
                            },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: store.data.themeMode == item.$1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 54,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  colors: item.$1 == 'system'
                                      ? [
                                          const Color(0xfff4f9f5),
                                          const Color(0xff17241e),
                                        ]
                                      : item.$1 == 'dark'
                                      ? [
                                          const Color(0xff17241e),
                                          const Color(0xff17241e),
                                        ]
                                      : [const Color(0xfff4f9f5), Colors.white],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: item.$1 == 'dark'
                                            ? const Color(0xff83d8ac)
                                            : const Color(0xff9dc7b5),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.$2,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.$3,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (store.data.themeMode == item.$1)
                              MenuIcon(
                                Icons.check_circle_outline,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            else
                              MenuIcon(
                                Icons.radio_button_unchecked,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
